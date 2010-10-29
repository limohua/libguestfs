/* libguestfs - guestfish and guestmount shared option parsing
 * Copyright (C) 2010 Red Hat Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef OPTIONS_H
#define OPTIONS_H

#ifdef HAVE_GETTEXT
#include "gettext.h"
#ifndef _
#define _(str) dgettext(PACKAGE, (str))
#endif
#ifndef N_
#define N_(str) dgettext(PACKAGE, (str))
#endif
#else
#ifndef _
#define _(str) str
#endif
#ifndef _
#define N_(str) str
#endif
#endif

#ifndef STREQ
#define STREQ(a,b) (strcmp((a),(b)) == 0)
#endif
#ifndef STRCASEEQ
#define STRCASEEQ(a,b) (strcasecmp((a),(b)) == 0)
#endif
#ifndef STRNEQ
#define STRNEQ(a,b) (strcmp((a),(b)) != 0)
#endif
#ifndef STRCASENEQ
#define STRCASENEQ(a,b) (strcasecmp((a),(b)) != 0)
#endif
#ifndef STREQLEN
#define STREQLEN(a,b,n) (strncmp((a),(b),(n)) == 0)
#endif
#ifndef STRCASEEQLEN
#define STRCASEEQLEN(a,b,n) (strncasecmp((a),(b),(n)) == 0)
#endif
#ifndef STRNEQLEN
#define STRNEQLEN(a,b,n) (strncmp((a),(b),(n)) != 0)
#endif
#ifndef STRCASENEQLEN
#define STRCASENEQLEN(a,b,n) (strncasecmp((a),(b),(n)) != 0)
#endif
#ifndef STRPREFIX
#define STRPREFIX(a,b) (strncmp((a),(b),strlen((b))) == 0)
#endif

/* Provided by guestfish or guestmount. */
extern guestfs_h *g;
extern int read_only;
extern int verbose;
extern int inspector;
extern const char *libvirt_uri;
extern const char *program_name;

/* List of drives added via -a, -d or -N options. */
struct drv {
  struct drv *next;
  enum { drv_a, drv_d, drv_N } type;
  union {
    struct {
      char *filename;       /* disk filename */
      const char *format;   /* format (NULL == autodetect) */
    } a;
    struct {
      char *guest;          /* guest name */
    } d;
    struct {
      char *filename;       /* disk filename (testX.img) */
      void *data;           /* prepared type */
      void (*data_free)(void*); /* function to free 'data' */
      char *device;         /* device inside the appliance */
    } N;
  };
};

struct mp {
  struct mp *next;
  char *device;
  char *mountpoint;
};

/* in inspect.c */
extern void inspect_mount (void);
extern void print_inspect_prompt (void);

/* in options.c */
extern char add_drives (struct drv *drv, char next_drive);
extern void mount_mps (struct mp *mp);
extern void free_drives (struct drv *drv);
extern void free_mps (struct mp *mp);

/* in virt.c */
extern int add_libvirt_drives (const char *guest);

#define OPTION_a                                \
  if (access (optarg, R_OK) != 0) {             \
    perror (optarg);                            \
    exit (EXIT_FAILURE);                        \
  }                                             \
  drv = malloc (sizeof (struct drv));           \
  if (!drv) {                                   \
    perror ("malloc");                          \
    exit (EXIT_FAILURE);                        \
  }                                             \
  drv->type = drv_a;                            \
  drv->a.filename = optarg;                     \
  drv->a.format = format;                       \
  drv->next = drvs;                             \
  drvs = drv

#define OPTION_c                                \
  libvirt_uri = optarg

#define OPTION_d                                \
  drv = malloc (sizeof (struct drv));           \
  if (!drv) {                                   \
    perror ("malloc");                          \
    exit (EXIT_FAILURE);                        \
  }                                             \
  drv->type = drv_d;                            \
  drv->d.guest = optarg;                        \
  drv->next = drvs;                             \
  drvs = drv

#define OPTION_i                                \
  inspector = 1

#define OPTION_m                                \
  mp = malloc (sizeof (struct mp));             \
  if (!mp) {                                    \
    perror ("malloc");                          \
    exit (EXIT_FAILURE);                        \
  }                                             \
  p = strchr (optarg, ':');                     \
  if (p) {                                      \
    *p = '\0';                                  \
    mp->mountpoint = p+1;                       \
  } else                                        \
    mp->mountpoint = bad_cast ("/");            \
  mp->device = optarg;                          \
  mp->next = mps;                               \
  mps = mp

#define OPTION_n                                \
  guestfs_set_autosync (g, 0)

#define OPTION_r                                \
  read_only = 1

#define OPTION_v                                \
  verbose++;                                    \
  guestfs_set_verbose (g, verbose)

#define OPTION_V                                                        \
  {                                                                     \
    struct guestfs_version *v = guestfs_version (g);                    \
    printf ("%s %"PRIi64".%"PRIi64".%"PRIi64"%s\n",                     \
            program_name,                                               \
            v->major, v->minor, v->release, v->extra);                  \
    exit (EXIT_SUCCESS);                                                \
  }

#define OPTION_x                                \
  guestfs_set_trace (g, 1)

#endif /* OPTIONS_H */