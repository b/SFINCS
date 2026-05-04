module sfincs_discharges_io

   use sfincs_log
   use sfincs_error

contains
   !
   subroutine read_discharges()
   !
   ! Reads discharge files
   !
   use sfincs_data
   use sfincs_ncinput
   use quadtree
   !
   implicit none
   !
   real*4, dimension(:),     allocatable :: xsnk
   real*4, dimension(:),     allocatable :: ysnk
   !
   real*4 dummy, xsnk_tmp, ysnk_tmp, xsrc_tmp, ysrc_tmp
   !
   integer isrc, itsrc, idrn, nm, m, n, stat, j, iref, nmq, npars
   !
   logical :: ok
   !
   character(len=256) :: drainage_line, message
   !
   ! Read discharge points
   !
   nsrc  = 0
   ndrn  = 0
   ntsrc = 0
   itsrclast = 1
   !
   if (srcfile(1:4) /= 'none') then
      !
      ok = check_file_exists(srcfile, 'Source points file', .true.)
      !
      write(logstr,'(a)')'Info    : reading discharges'
      call write_log(logstr, 0)
      !
      ok = check_file_exists(srcfile, 'River input locations src file', .true.)
      !
      open(500, file=trim(srcfile))
      do while(.true.)
         read(500,*,iostat = stat)dummy
         if (stat < 0) exit
         nsrc = nsrc + 1
      enddo
      rewind(500)
      !
   elseif (netsrcdisfile(1:4) /= 'none') then    ! FEWS compatible Netcdf discharge time-series input
      !
      ok = check_file_exists(netsrcdisfile, 'Netcdf river input netsrcdis file', .true.)
      !
      call read_netcdf_discharge_data()  ! reads nsrc, ntsrc, xsrc, ysrc, qsrc, and tsrc
      !
      if ((tsrc(1) > (t0 + 1.0)) .or. (tsrc(ntsrc) < (t1 - 1.0))) then
         !
         write(logstr,'(a)')' WARNING! Times in discharge file do not cover entire simulation period!'
         call write_log(logstr, 1)
         !
      endif
      !
   endif
   !
   if (drnfile(1:4) /= 'none') then
      !
      write(logstr,'(a)')'Info    : reading drainage file'
      call write_log(logstr, 0)
      !
      ok = check_file_exists(drnfile, 'Drainage points drn file', .true.)
      !
      open(501, file=trim(drnfile))
      do while(.true.)
         read(501,*,iostat = stat)dummy
         if (stat < 0) exit
         ndrn = ndrn + 1
      enddo
      rewind(501)
   endif
   !
   nsrcdrn = nsrc + 2 * ndrn
   !
   if (nsrcdrn > 0) then
      allocate(nmindsrc(nsrcdrn))
      allocate(qtsrc(nsrcdrn))
      nmindsrc = 0
      qtsrc = 0.0
   endif
   !
   if (srcfile(1:4) /= 'none') then
      !
      ! Actually read src and dis files
      !
      allocate(xsrc(nsrc))
      allocate(ysrc(nsrc))
      !
      do n = 1, nsrc
         read(500,*)xsrc(n), ysrc(n)
      enddo
      close(500)
      !
      ! Read discharge time series
      !
      ok = check_file_exists(disfile, 'River discharge timeseries dis file', .true.)
      !
      open(502, file=trim(disfile))
      do while(.true.)
         read(502,*,iostat = stat)dummy
         if (stat < 0) exit
         ntsrc = ntsrc + 1
      enddo
      rewind(502)
      allocate(tsrc(ntsrc))
      allocate(qsrc(nsrc,ntsrc))
      do itsrc = 1, ntsrc
         read(502,*)tsrc(itsrc), (qsrc(isrc, itsrc), isrc = 1, nsrc)
      enddo
      close(502)
      !
      if ((tsrc(1) > (t0 + 1.0)) .or. (tsrc(ntsrc) < (t1 - 1.0))) then
         !
         write(logstr,'(a)')'Warning! Times in discharge file do not cover entire simulation period !'
         call write_log(logstr, 1)
         !
         if (tsrc(1) > (t0 + 1.0)) then
            !
            write(logstr,'(a)')'Warning! Adjusting first time in discharge time series !'
            call write_log(logstr, 1)
            !
            tsrc(1) = t0 - 1.0
            !
         else
            !
            write(logstr,'(a)')'Warning! Adjusting last time in discharge time series !'
            call write_log(logstr, 1)
            !
            tsrc(ntsrc) = t1 + 1.0
            !
         endif
         !
      endif
      !
   endif
   !
   if (nsrc > 0) then
      !
      ! Determine m and n indices of sources
      !
      do isrc = 1, nsrc
         !
         ! Find cell in quadtree first
         !
         nmq = find_quadtree_cell(xsrc(isrc), ysrc(isrc))
         !
         if (nmq > 0) then
            !
            nmindsrc(isrc) = index_sfincs_in_quadtree(nmq)
            !
         endif
         !
      enddo
      !
      ! Don't need coordinates anymore, and xsrc and ysrc may be used for drainage points as well
      !
      deallocate(xsrc)
      deallocate(ysrc)
      !
   endif
   !
   ! And now the drainage points
   !
   if (ndrn>0) then
      !
      write(logstr,'(a,a,a,i0,a)')' Reading ',trim(drnfile),' (', ndrn, ' drainage points found) ...'
      call write_log(logstr, 0)
      !
      allocate(xsrc(ndrn))
      allocate(ysrc(ndrn))
      allocate(xsnk(ndrn))
      allocate(ysnk(ndrn))
      !
      allocate(drainage_type(ndrn))
      allocate(drainage_params(ndrn, 6))
      allocate(drainage_status(ndrn))
      allocate(drainage_distance(ndrn))
      allocate(drainage_fraction_open(ndrn))
      !
      drainage_params = 0.0
      drainage_distance = 0.0
      drainage_fraction_open = 1.0   ! initially fully open (should fix this based on zmin and zmax in params)
      drainage_status = 1            ! open (0=closed, 1=open, 2=closing, 3=opening)
      !
      do idrn = 1, ndrn
         !
         read(501, '(a)') drainage_line
         !
         ! First find out what type of drainage structure it is (integer 5th item in line)
         !
         read(drainage_line,*,iostat=stat)xsnk_tmp, ysnk_tmp, xsrc_tmp, ysrc_tmp, drainage_type(idrn)
         !
         npars = 0 ! Default (if npars stays 0, throw error)
         !
         if (drainage_type(idrn) == 1 .or. drainage_type(idrn) == 2 .or. drainage_type(idrn) == 3) then
            !
            ! Pump, culvert or check valve (1 parameter)
            !
            npars = 1
            !
         elseif (drainage_type(idrn) == 4 .or. drainage_type(idrn) == 5) then
            !
            ! Controlled gate (6 parameters : width, sill elevation, manning, zmin, zmax, closing time)
            !
            npars = 6
            !
         endif
         !
         if (npars == 0) then
            !
            write(logstr,'(a,i0,a)')'Drainage type ', drainage_type(idrn), ' not recognized !'
            call stop_sfincs(logstr, -1)
            !
         endif
         !
         if (npars == 1) then
            !
            ! Pump, culvert or check valve
            !
            read(drainage_line,*,iostat=stat)xsnk(idrn), ysnk(idrn), xsrc(idrn), ysrc(idrn), drainage_type(idrn), drainage_params(idrn,1)
            !
         elseif (npars == 6) then
            !
            ! Controlled gate, needs 6 parameters
            !
            read(drainage_line,*,iostat=stat)xsnk(idrn), ysnk(idrn), xsrc(idrn), ysrc(idrn), drainage_type(idrn), drainage_params(idrn,1), drainage_params(idrn,2), drainage_params(idrn,3), drainage_params(idrn,4), drainage_params(idrn,5), drainage_params(idrn,6)
            !
         endif
         !
         if (stat /= 0) then
            !
            write(logstr,'(a,i0,a,i0,a)')'Drainage type ', drainage_type(idrn), ' requires ', npars, ' parameters !'
            call stop_sfincs(logstr, -1)
            !
         endif
         !
      enddo
      !
      close(501)
      !
      ! Determine nm indices of source and sinks
      !
      do idrn = 1, ndrn
         !
         ! Determine index of sink first
         !
         j = nsrc + idrn*2 - 1
         !
         nmq = find_quadtree_cell(xsnk(idrn), ysnk(idrn))
         !
         if (nmq > 0) then
            !
            nmindsrc(j) = index_sfincs_in_quadtree(nmq)
            !
         endif
         !
         ! And now the index of the source
         !
         j = nsrc + idrn * 2
         !
         nmq = find_quadtree_cell(xsrc(idrn), ysrc(idrn))
         !
         if (nmq > 0) then
            !
            nmindsrc(j) = index_sfincs_in_quadtree(nmq)
            !
         endif
         !
         ! Get coords of source and sink points, and compute distance between them
         ! This is needed for controlled gates (type 4)
         !
         xsnk_tmp = z_xz(nmindsrc(nsrc + idrn * 2 - 1))
         ysnk_tmp = z_yz(nmindsrc(nsrc + idrn * 2 - 1))
         xsrc_tmp = z_xz(nmindsrc(nsrc + idrn * 2))
         ysrc_tmp = z_yz(nmindsrc(nsrc + idrn * 2))
         !
         drainage_distance(idrn) = sqrt( (xsrc_tmp - xsnk_tmp)**2 + (ysrc_tmp - ysnk_tmp)**2 )
         !
      enddo
      !
      deallocate(xsrc)
      deallocate(ysrc)
      deallocate(xsnk)
      deallocate(ysnk)
      !
      ! Check if all sink/source points have found an index
      if (any(nmindsrc == 0)) then
         !
         write(logstr,'(a)')'Warning ! For some sink/source drainage points no matching active grid cell was found!'
         call write_log(logstr, 0)
         write(logstr,'(a)')'Warning ! These points will be skipped, please check your input!'
         call write_log(logstr, 0)
         !
      endif
      !
   endif
   !
   end subroutine

end module
