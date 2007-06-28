/*
   env-update
   Create /etc/profile.env (sh), /etc/csh.env from /etc/env.d
   Run ldconfig as required

   Copyright 2007 Gentoo Foundation
   Released under the GPLv2

*/

#define APPLET "env-update"

#include <errno.h>
#include <getopt.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "einfo.h"
#include "rc.h"
#include "rc-misc.h"
#include "strlist.h"

#define ENVDIR      "/etc/env.d"
#define PROFILE_ENV "/etc/profile.env"
#define CSH_ENV     "/etc/csh.env"
#define LDSOCONF    "/etc/ld.so.conf"

#define NOTICE      "# THIS FILE IS AUTOMATICALLY GENERATED BY env-update.\n" \
                    "# DO NOT EDIT THIS FILE. CHANGES TO STARTUP PROFILES\n" \
                    "# GO INTO %s NOT %s\n\n"

#define LDNOTICE    "# ld.so.conf autogenerated by env-update; make all\n" \
                    "# changes to contents of /etc/env.d directory\n"

static const char *colon_separated[] = {
	"ADA_INCLUDE_PATH",
	"ADA_OBJECTS_PATH",
	"CLASSPATH",
	"INFOPATH",
	"KDEDIRS",
	"LDPATH",
	"MANPATH",
	"PATH",
	"PKG_CONFIG_PATH",
	"PRELINK_PATH",
	"PRELINK_PATH_MASK",
	"PYTHONPATH",
	"ROOTPATH",
	NULL
};

static const char *space_separated[] = { 
	"CONFIG_PROTECT",
	"CONFIG_PROTECT_MASK",
	NULL,
};

static char *applet = NULL;

#include "_usage.h"
#define getoptstring "L" getoptstring_COMMON
static struct option longopts[] = {
	{ "no-ldconfig",    0, NULL, 'L'},
	longopts_COMMON
	{ NULL,             0, NULL, 0}
};
#include "_usage.c"

int main (int argc, char **argv)
{
	char **files = rc_ls_dir (NULL, ENVDIR, 0);
	char *file;
	char **envs = NULL;
	char *env;
	int i = 0;
	int j;
	FILE *fp;
	bool ld = true;
	char *ldent;
	char **ldents = NULL;
	int nents = 0;
	char **config = NULL;
	char *entry;
	char **mycolons = NULL;
	char **myspaces = NULL;
	int opt;
	bool ldconfig = true;
	
	applet = argv[0];

	while ((opt = getopt_long (argc, argv, getoptstring,
							   longopts, (int *) 0)) != -1)
	{
		switch (opt) {
			case 'L':
				ldconfig = false;
				break;

			case_RC_COMMON_GETOPT
		}
	}

	if (! files)
		eerrorx ("%s: no files in " ENVDIR " to process", applet);

	STRLIST_FOREACH (files, file, i) {
		char *path = rc_strcatpaths (ENVDIR, file, (char *) NULL);
		char **entries = NULL;

		if (! rc_is_dir (path))
			entries = rc_get_config (NULL, path);
		free (path);

		STRLIST_FOREACH (entries, entry, j) {
			char *tmpent = rc_xstrdup (entry);
			char *value = tmpent;
			char *var = strsep (&value, "=");

			if (strcmp (var, "COLON_SEPARATED") == 0)
				while ((var = strsep (&value, " ")))
					mycolons = rc_strlist_addu (mycolons, var);
			else if (strcmp (var, "SPACE_SEPARATED") == 0)
				while ((var = strsep (&value, " ")))
					myspaces = rc_strlist_addu (myspaces, var);
			else
				config = rc_strlist_add (config, entry);
			free (tmpent);
		}

		rc_strlist_free (entries);
	}

	STRLIST_FOREACH (config, entry, i) {
		char *tmpent = rc_xstrdup (entry);
		char *value = tmpent;
		char *var = strsep (&value, "=");
		char *match;
		bool colon = false;
		bool space = false;
		bool replaced = false;

		for (j = 0; colon_separated[j]; j++)
			if (strcmp (colon_separated[j], var) == 0) {
				colon = true;
				break;
			}

		if (! colon)
			STRLIST_FOREACH  (mycolons, match, j) {
				if (strcmp (match, var) == 0) {
					colon = true;
					break;
				} }

		if (! colon)
			for (j = 0; space_separated[j]; j++)
				if (strcmp (space_separated[j], var) == 0) {
					space = true;
					break;
				}

		if (! colon && ! space)
			STRLIST_FOREACH  (myspaces, match, j)
				if (strcmp (match, var) == 0) {
					space = true;
					break;
				}

		/* Skip blank vars */
		if ((colon || space) &&
			(! value || strlen (value)) == 0)
		{
			free (tmpent);
			continue;
		}

		STRLIST_FOREACH (envs, env, j) {
			char *tmpenv = rc_xstrdup (env);
			char *tmpvalue = tmpenv;
			char *tmpentry = strsep (&tmpvalue, "=");

			if (strcmp (tmpentry, var) == 0) {
				if (colon || space) {
					int len =  strlen (envs[j - 1]) + strlen (entry) + 1;
					envs[j - 1] = rc_xrealloc (envs[j - 1], len);
					snprintf (envs[j - 1] + strlen (envs[j - 1]), len,
							  "%s%s", colon ? ":" : " ", value);
				} else {
					free (envs[j - 1]);
					envs[j - 1] = rc_xstrdup (entry);
				}
				replaced = true;
			}
			free (tmpenv);

			if (replaced)
				break;
		}

		if (! replaced)
			envs = rc_strlist_addsort (envs, entry);

		free (tmpent);
	}
	rc_strlist_free (mycolons);
	rc_strlist_free (myspaces);
	rc_strlist_free (config);
	rc_strlist_free (files);

	if ((fp = fopen (PROFILE_ENV, "w")) == NULL)
		eerrorx ("%s: fopen `%s': %s", applet, PROFILE_ENV, strerror (errno));
	fprintf (fp, NOTICE, "/etc/profile", PROFILE_ENV);

	STRLIST_FOREACH (envs, env, i) {
		char *tmpent = rc_xstrdup (env);
		char *value = tmpent;
		char *var = strsep (&value, "=");
		if (strcmp (var, "LDPATH") != 0)
			fprintf (fp, "export %s='%s'\n", var, value);
		free (tmpent);
	}
	fclose (fp);

	if ((fp = fopen (CSH_ENV, "w")) == NULL)
		eerrorx ("%s: fopen `%s': %s", applet, PROFILE_ENV, strerror (errno));
	fprintf (fp, NOTICE, "/etc/csh.cshrc", PROFILE_ENV);

	STRLIST_FOREACH (envs, env, i) {
		char *tmpent = rc_xstrdup (env);
		char *value = tmpent;
		char *var = strsep (&value, "=");
		if (strcmp (var, "LDPATH") != 0)
			fprintf (fp, "setenv %s '%s'\n", var, value);
		free (tmpent);
	}
	fclose (fp);

	ldent = rc_get_config_entry (envs, "LDPATH");

	if (! ldent ||
		(argc > 1 && argv[1] && strcmp (argv[1], "--no-ldconfig") == 0))
	{
		rc_strlist_free (envs);
		return (EXIT_SUCCESS);
	}

	while ((file = strsep (&ldent, ":"))) {
		if (strlen (file) == 0)
			continue;

		ldents = rc_strlist_add (ldents, file);
		nents++;
	}

	if (ldconfig) {
		/* Update ld.so.conf only if different */
		if (rc_exists (LDSOCONF)) {
			char **lines = rc_get_list (NULL, LDSOCONF);
			char *line;
			ld = false;
			STRLIST_FOREACH (lines, line, i)
				if (i > nents || strcmp (line, ldents[i - 1]) != 0)
				{
					ld = true;
					break;
				}
			rc_strlist_free (lines);
			if (i - 1 != nents)
				ld = true;
		}

		if (ld) {
			int retval = 0;

			if ((fp = fopen (LDSOCONF, "w")) == NULL)
				eerrorx ("%s: fopen `%s': %s", applet, LDSOCONF,
						 strerror (errno));
			fprintf (fp, LDNOTICE);
			STRLIST_FOREACH (ldents, ldent, i)
				fprintf (fp, "%s\n", ldent);
			fclose (fp);

#if defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__)
			ebegin ("Regenerating /var/run/ld-elf.so.hints");
			retval = system ("/sbin/ldconfig -elf -i '" LDSOCONF "'");
#else
			ebegin ("Regenerating /etc/ld.so.cache");
			retval = system ("/sbin/ldconfig");
#endif
			eend (retval, NULL);
		}
	}

	rc_strlist_free (ldents);
	rc_strlist_free (envs);
	return(EXIT_SUCCESS);
}
