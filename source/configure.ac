#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
dnl we are using autoconf
AC_INIT([SFINCS], [0.1], [tim.leijnse@deltares.nl])
dnl automake
AM_INIT_AUTOMAKE([subdir-objects])
dnl and libtool
LT_INIT

dnl this is how to find the source directory
AC_CONFIG_SRCDIR([src/sfincs.f90])
dnl this is th file with header flags, you can use this file in .F90 files
AC_CONFIG_HEADERS([config.h])
dnl m4 macro's in m4 directory.
AC_CONFIG_MACRO_DIR([m4])

# Checks for programs.
dnl we need a fortran compiler
AC_PROG_FC
dnl also the c compiler for OpenACC/OpenMP checks
AC_PROG_CC
dnl and the preprocessor
AC_PROG_CPP
dnl just to make clear that we have f90 as extension
AC_FC_SRCEXT([f90])
dnl Yes, we want free form Fortran!
AC_FC_FREEFORM
AC_FC_LINE_LENGTH([unlimited])

dnl detect openmp
AC_LANG_PUSH([Fortran])
AC_OPENMP
dnl detect openacc flag
AX_OPENACC
AC_LANG_POP

dnl optional CUDA Fortran build (requires nvfortran)
AC_ARG_ENABLE([cuda],
   AS_HELP_STRING([--enable-cuda], [Build with CUDA Fortran (requires nvfortran)]),
   [enable_cuda=$enableval], [enable_cuda=no])

AM_CONDITIONAL([USE_CUDA], [test "x$enable_cuda" = "xyes"])

AS_IF([test "x$enable_cuda" = "xyes"], [
   AC_DEFINE([USE_CUDA], [1], [Build with CUDA Fortran kernels])
   # Verify nvfortran
   AS_IF([test "$FC" = "nvfortran" -o -n "`echo $FC | grep nvfortran`"], [],
      [AC_MSG_ERROR([--enable-cuda requires FC=nvfortran])])
   # Append CUDA flags. -Kieee disables the non-IEEE shortcuts that `-fast`
   # enables (FMA contraction, denormal flushing, reciprocal approximations,
   # reassociation), so nvfortran's float arithmetic matches gfortran's
   # default IEEE-strict behavior. Required for CPU/GPU numeric agreement.
   FCFLAGS="$FCFLAGS -cuda -gpu=cc86,cc80,cc90 -Kieee -DUSE_CUDA"
])

dnl MPI detection for CUDA builds (NVHPC HPC-X provides mpifort wrapping nvfortran).
dnl Gated on --enable-cuda so CPU builds never invoke mpifort.
AC_SUBST([MPI_FCFLAGS])
AC_SUBST([MPI_LIBS])
AS_IF([test "x$enable_cuda" = "xyes"], [
   AC_PATH_PROG([MPIFORT], [mpifort])
   AS_IF([test -z "$MPIFORT"],
      [AC_MSG_ERROR([mpifort required for --enable-cuda; install NVHPC HPC-X or set PATH])])
   MPI_FCFLAGS=`$MPIFORT --showme:compile 2>/dev/null`
   MPI_LIBS=`$MPIFORT --showme:link 2>/dev/null`
   dnl libtool unwraps -Wl,FOO to bare FOO before passing to FC; nvfortran
   dnl then rejects flags it does not recognise (e.g. --enable-new-dtags).
   dnl Strip linker-only -Wl,FOO directives so libtool's own rpath handling
   dnl drives the link step.
   MPI_LIBS=`echo " $MPI_LIBS " | sed 's/ -Wl,[[^ ]]*//g'`
   AS_IF([test -z "$MPI_FCFLAGS" -o -z "$MPI_LIBS"],
      [AC_MSG_ERROR([mpifort --showme:compile/--showme:link failed; HPC-X / OpenMPI required (MPICH -compile_info syntax not supported)])])
   AC_MSG_NOTICE([MPI_FCFLAGS=$MPI_FCFLAGS])
   AC_MSG_NOTICE([MPI_LIBS=$MPI_LIBS])
])


# NetCDF, the c version
dnl the fortran version is compiled in place so we can link it statically
PKG_CHECK_MODULES(NETCDF, netcdf >= 4)


# Checks for libraries.

# Checks for header files.
dnl we might need to add netcdf here later
AC_CHECK_HEADERS([])

# Checks for typedefs, structures, and compiler characteristics.
AC_TYPE_SIZE_T
dnl for later
AC_CHECK_TYPES([])

# Checks for library functions.
dnl for debugging
AC_FUNC_ERROR_AT_LINE
dnl we might need to add netcdf function here to check if it works
AC_CHECK_FUNCS([])

dnl these are our makefiles
AC_CONFIG_FILES([
        Makefile
        src/Makefile
])
dnl we'll try to include netcdf-fortran in the binary so all fortran code is portable
AC_CONFIG_SUBDIRS([third_party_open/netcdf/netcdf-fortran-4.6.1])
AC_OUTPUT
