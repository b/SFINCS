   module sfincs_wavemaker_io

   use sfincs_log
   use sfincs_error

   contains

   subroutine initialize_wavemakers()
   !
   ! Reads polylines files
   ! Computes cross sections
   ! Determines interpolation weights
   ! Interpolates bathymetry
   !
   use sfincs_data
   use quadtree
   !
   implicit none
   !wavemaker_nfreqs_ig
   integer*4 :: nrows
   integer*4 :: ncols
   integer*4 :: stat
   integer*4 :: ipol
   integer*4 :: irow   
   integer*4 :: j
   integer*4 :: n
   integer*4 :: nmu
   integer*4 :: nrw
   integer*4 :: ip
   integer*4 :: iwm
   integer*4 :: iz
   integer*4 :: nr_cells
   integer*4 :: nok
   integer*4 :: ifreq
   integer*4 :: itb
   !
   real*4    :: dummy
   real*4    :: phip
   !
   real*4    :: r
   !
   character :: cdummy
   !
   real*4,    dimension(:),     allocatable :: xpol
   real*4,    dimension(:),     allocatable :: ypol
   real*4,    dimension(:),     allocatable :: phi
   !
   integer*4, dimension(:),     allocatable :: cell_indices
   integer*4, dimension(:),     allocatable :: indwm
   !
   real*4, dimension(:),     allocatable :: wavemaker_xfp
   real*4, dimension(:),     allocatable :: wavemaker_yfp   
   !
   logical :: iok, ok
   !
   integer ib1, ib2, ib, ic, nmb, nrwvm
   !
   real x, y, dst1, dst2, dst
   !
   allocate(indwm(np))
   allocate(phi(np))
   !
   indwm = 0
   phi   = 0.0
   !
   nrw = 0
   nrwvm = 0
   !
   write(logstr,*)'Reading wavemaker polyline file ...'
   call write_log(logstr, 0)
   !
   ok = check_file_exists(wavemaker_wvmfile, 'Wave maker wvm file', .true.)
   !
   open(500, file=trim(wavemaker_wvmfile))
   do while(.true.)
      read(500,*,iostat = stat)cdummy
      if (stat<0) exit      
      read(500,*,iostat = stat)nrows,ncols
      if (stat<0) exit
      nrwvm = nrwvm + 1
      do irow = 1, nrows
         read(500,*)dummy
      enddo
   enddo
   rewind(500)
   !
   ! Loop through polylines
   !
   write(logstr,*)'Number of wavemaker polylines found : ', nrwvm
   call write_log(logstr, 0)   
   !
   do ipol = 1, nrwvm
      !
      read(500,*,iostat = stat)cdummy
      if (stat<0) exit
      read(500,*,iostat = stat)nrows,ncols
      if (stat<0) exit
      allocate(xpol(nrows))
      allocate(ypol(nrows))
      do irow = 1, nrows
         read(500,*)xpol(irow),ypol(irow)
      enddo   
      !
      do irow = 1, nrows - 1
         !
         ! Determine angle with respect to grid orientation
         !
         phip = atan2(ypol(irow + 1) - ypol(irow), xpol(irow + 1) - xpol(irow)) + 0.5 * pi
         phip = phip - rotation
         if (phip >= 2 * pi) phip = phip - 2 * pi
         if (phip < 0.0)   phip = phip + 2 * pi
         !
         call find_cells_intersected_by_line(cell_indices, nr_cells, xpol(irow), ypol(irow), xpol(irow + 1), ypol(irow + 1))
         !
         do j = 1, nr_cells
            !
            ip = index_sfincs_in_quadtree(cell_indices(j))
            !
            if (ip > 0) then
               !
               if (indwm(ip) == 0) then
                  !
                  indwm(ip) = 1 ! set temporary flag to 1
                  phi(ip)   = phip
                  nrw       = nrw + 1
                  !
               endif   
            endif             
            !
         enddo  
         !
      enddo
      !
      deallocate(xpol)
      deallocate(ypol)      
      !
   enddo   
   !
   close(500)
   !
   ! Now get rid of cells that have neighbor closer to shore that is also a wavemaker point
   !
   nok = 0
   !
   do ip = 1, np
      !
      ! Check if these cells have neighbor closer to shore that is also a wavemaker point
      !
      if (indwm(ip) == 1) then
         !
         iok = .false.
         !
         if (phi(ip) >= 0.0 .and. phi(ip) < 0.5 * pi) then
            !
            ! Check right and above
            !
            nmu = z_index_uv_mu1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu > 0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (indwm(iz) == 0) then
                  !
                  ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                  !
                  iok = .true.
                  !
               endif   
            endif
            !
            if (.not. iok) then
               !
               nmu = z_index_uv_mu2(ip)    ! index of 2nd uv neighbor to the right
               !
               if (nmu > 0) then
                  !
                  iz = uv_index_z_nmu(nmu)
                  !
                  if (indwm(iz) == 0) then
                     !
                     ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                     !
                     iok = .true.
                     !
                  endif   
               endif
            endif
            !
            if (.not. iok) then
               !
               nmu = z_index_uv_nu1(ip)    ! index of 1st uv neighbor above
               !
               if (nmu>0) then
                  !
                  iz = uv_index_z_nmu(nmu)
                  !
                  if (indwm(iz)==0) then
                     !
                     ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                     !
                     iok = .true.
                     !
                  endif   
               endif
            endif
            !
            if (.not. iok) then
               !
               nmu = z_index_uv_nu2(ip)    ! index of 2nd uv neighbor above
               !
               if (nmu>0) then
                  !
                  iz = uv_index_z_nmu(nmu)
                  !
                  if (indwm(iz)==0) then
                     !
                     ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                     !
                     iok = .true.
                     !
                  endif   
               endif
            endif
            !
         elseif (phi(ip)>=0.5*pi .and. phi(ip)<pi) then
            !
            ! Check left and above
            !
            nmu = z_index_uv_md1(ip)    ! index of 1st uv neighbor to the left
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (indwm(iz)==0) then
                  !
                  ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                  !
                  iok = .true.
                  !
               endif   
            endif
            !
            if (.not. iok) then
               !
               nmu = z_index_uv_md2(ip)    ! index of 2nd uv neighbor to the left
               !
               if (nmu>0) then
                  !
                  iz = uv_index_z_nm(nmu)
                  !
                  if (indwm(iz)==0) then
                     !
                     ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                     !
                     iok = .true.
                     !
                  endif   
               endif
            endif
            !
            if (.not. iok) then
               !
               nmu = z_index_uv_nu1(ip)    ! index of 1st uv neighbor above
               !
               if (nmu>0) then
                  !
                  iz = uv_index_z_nmu(nmu)
                  !
                  if (indwm(iz)==0) then
                     !
                     ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                     !
                     iok = .true.
                     !
                  endif   
               endif
            endif
            !
            if (.not. iok) then
               !
               nmu = z_index_uv_nu2(ip)    ! index of 2nd uv neighbor above
               !
               if (nmu>0) then
                  !
                  iz = uv_index_z_nmu(nmu)
                  !
                  if (indwm(iz)==0) then
                     !
                     ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                     !
                     iok = .true.
                     !
                  endif   
               endif
            endif
            !
         elseif (phi(ip)>=1.0*pi .and. phi(ip)<1.5*pi) then
            !
            ! Check left and below
            !
            nmu = z_index_uv_md1(ip)    ! index of 1st uv neighbor to the left
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (indwm(iz)==0) then
                  !
                  ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                  !
                  iok = .true.
                  !
               endif   
            endif
            !
            if (.not. iok) then
               !
               nmu = z_index_uv_md2(ip)    ! index of 2nd uv neighbor to the left
               !
               if (nmu>0) then
                  !
                  iz = uv_index_z_nm(nmu)
                  !
                  if (indwm(iz)==0) then
                     !
                     ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                     !
                     iok = .true.
                     !
                  endif   
               endif
            endif
            !
            if (.not. iok) then
               !
               nmu = z_index_uv_nd1(ip)    ! index of 1st uv neighbor below
               !
               if (nmu>0) then
                  !
                  iz = uv_index_z_nm(nmu)
                  !
                  if (indwm(iz)==0) then
                     !
                     ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                     !
                     iok = .true.
                     !
                  endif   
               endif
            endif
            !
            if (.not. iok) then
               !
               nmu = z_index_uv_nd2(ip)    ! index of 2nd uv neighbor below
               !
               if (nmu>0) then
                  !
                  iz = uv_index_z_nm(nmu)
                  !
                  if (indwm(iz)==0) then
                     !
                     ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                     !
                     iok = .true.
                     !
                  endif   
               endif
            endif
            !
         else
            !
            ! Check right and below
            !
            nmu = z_index_uv_mu1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (indwm(iz)==0) then
                  !
                  ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                  !
                  iok = .true.
                  !
               endif   
            endif
            !
            if (.not. iok) then
               !
               nmu = z_index_uv_mu2(ip)    ! index of 2nd uv neighbor to the right
               !
               if (nmu>0) then
                  !
                  iz = uv_index_z_nmu(nmu)
                  !
                  if (indwm(iz)==0) then
                     !
                     ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                     !
                     iok = .true.
                     !
                  endif   
               endif
            endif
            !
            if (.not. iok) then
               !
               nmu = z_index_uv_nd1(ip)    ! index of 1st uv neighbor below
               !
               if (nmu>0) then
                  !
                  iz = uv_index_z_nm(nmu)
                  !
                  if (indwm(iz)==0) then
                     !
                     ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                     !
                     iok = .true.
                     !
                  endif   
               endif
            endif
            !
            if (.not. iok) then
               !
               nmu = z_index_uv_nd2(ip)    ! index of 2nd uv neighbor below
               !
               if (nmu>0) then
                  !
                  iz = uv_index_z_nm(nmu)
                  !
                  if (indwm(iz)==0) then
                     !
                     ! This neighbor is not a wavemaker, so this point is a valid wave maker point
                     !
                     iok = .true.
                     !
                  endif   
               endif
            endif
         endif   
         !
         if (iok .and. kcs(ip) == 1) then
            !
            ! This is a valid wave maker point
            !
            kcs(ip) = 4
            !
            nok = nok + 1
            !
         endif   
         !
      endif      
   enddo   
   !
   allocate(z_index_wavemaker(np))
   z_index_wavemaker = 0
   !
   allocate(wavemaker_nmd(nok))
   allocate(wavemaker_nmu(nok))
   allocate(wavemaker_ndm(nok))
   allocate(wavemaker_num(nok))
   wavemaker_nmd = 0
   wavemaker_nmu = 0
   wavemaker_ndm = 0
   wavemaker_num = 0
   !
   ! Now set the uv wave maker points (first count them)
   !
   iwm = 0
   nok = 0
   !
   do ip = 1, np
      !
      if (kcs(ip)==4) then
         !
         nok = nok + 1
         !
         z_index_wavemaker(ip) = nok
         !
         if (phi(ip) >= 0.0 .and. phi(ip) < 0.5*pi) then
            !
            ! Check right
            !
            nmu = z_index_uv_mu1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_mu2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
            ! Check above
            !
            nmu = z_index_uv_nu1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_nu2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
         elseif (phi(ip)>=0.5*pi .and. phi(ip)<1.0*pi) then
            !
            ! Check left
            !
            nmu = z_index_uv_md1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_md2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
            ! Check above
            !
            nmu = z_index_uv_nu1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_nu2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
         elseif (phi(ip)>=1.0*pi .and. phi(ip)<1.5*pi) then
            !
            ! Check left
            !
            nmu = z_index_uv_md1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_md2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
            ! Check below
            !
            nmu = z_index_uv_nd1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_nd2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
         else
            !
            ! Check right
            !
            nmu = z_index_uv_mu1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_mu2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
            ! Check below
            !
            nmu = z_index_uv_nd1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_nd2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !
               endif
               !
            endif   
            !
         endif
      endif
   enddo   
   !
   ! Allocate arrays
   !
   write(logstr,*)'Number of wavemaker u/v points : ', iwm
   call write_log(logstr, 0)
   !
   wavemaker_nr_uv_points = iwm   
   !
   allocate(wavemaker_index_uv(iwm))
   allocate(wavemaker_index_nmi(iwm))
   allocate(wavemaker_index_nmb(iwm))
   allocate(wavemaker_idir(iwm))
   allocate(wavemaker_angfac(iwm))
   allocate(wavemaker_uvmean(iwm))
   allocate(wavemaker_uvtrend(iwm))
   !
   wavemaker_uvmean  = 0.0
   wavemaker_uvtrend = 0.0
   !
   ! Okay, we counted the number of uv wavemaker points
   ! Now let's set them (same procedure)
   !
   iwm = 0
   nok = 0
   !
   write(logstr,*)'Setting wave makers ...'
   call write_log(logstr, 0)   
   !
   do ip = 1, np
      !
      if (kcs(ip)==4) then
         !
         nok = nok + 1
         !
         if (phi(ip)>=0.0 .and. phi(ip)<0.5*pi) then
            !
            ! Check right
            !
            nmu = z_index_uv_mu1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = 1
                  wavemaker_angfac(iwm)    = max(cos(phi(ip) - 0.0), 0.0)
                  !
                  wavemaker_nmu(nok) = iwm
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_mu2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = 1
                  wavemaker_angfac(iwm)    = max(cos(phi(ip) - 0.0), 0.0)
                  !
               endif
               !
            endif   
            !
            ! Check above
            !
            nmu = z_index_uv_nu1(ip)    ! index of 1st uv neighbor above
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = 1
                  wavemaker_angfac(iwm)    = max(sin(phi(ip) - 0.0), 0.0)
                  !
                  wavemaker_num(nok) = iwm
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_nu2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = 1
                  wavemaker_angfac(iwm)    = max(sin(phi(ip) - 0.0), 0.0)
                  !
               endif
               !
            endif   
            !
         elseif (phi(ip)>=0.5*pi .and. phi(ip)<1.0*pi) then
            !
            ! Check left
            !
            nmu = z_index_uv_md1(ip)    ! index of 1st uv neighbor to the left
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = -1
                  wavemaker_angfac(iwm)    = max(cos(pi - phi(ip)), 0.0)
                  !
                  wavemaker_nmd(nok) = iwm
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_md2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = -1
                  wavemaker_angfac(iwm)    = max(cos(pi - phi(ip)), 0.0)
                  !
               endif
               !
            endif   
            !
            ! Check above
            !
            nmu = z_index_uv_nu1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = 1
                  wavemaker_angfac(iwm)    = max(sin(phi(ip) - 0.0), 0.0)
                  !
                  wavemaker_num(nok) = iwm
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_nu2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = 1
                  wavemaker_angfac(iwm)    = max(sin(phi(ip) - 0.0), 0.0)
                  !
               endif
               !
            endif   
            !
         elseif (phi(ip)>=1.0*pi .and. phi(ip)<1.5*pi) then
            !
            ! Check left
            !
            nmu = z_index_uv_md1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = -1
                  wavemaker_angfac(iwm)    = max(cos(pi - phi(ip)), 0.0)
                  !
                  wavemaker_nmd(nok) = iwm
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_md2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = -1
                  wavemaker_angfac(iwm)    = max(cos(pi - phi(ip)), 0.0)
                  !
               endif
               !
            endif   
            !
            ! Check below
            !
            nmu = z_index_uv_nd1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = -1
                  wavemaker_angfac(iwm)    = max(sin(pi - phi(ip)), 0.0)
                  !
                  wavemaker_ndm(nok) = iwm
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_nd2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = -1
                  wavemaker_angfac(iwm)    = max(sin(pi - phi(ip)), 0.0)
                  !
               endif
               !
            endif   
         else
            !
            ! Check right
            !
            nmu = z_index_uv_mu1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = 1
                  wavemaker_angfac(iwm)    = max(cos(phi(ip) - 0.0), 0.0)
                  !
                  wavemaker_nmu(nok) = iwm
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_mu2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nmu(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = 1
                  wavemaker_angfac(iwm)    = max(cos(phi(ip) - 0.0), 0.0)
                  !
               endif
               !
            endif   
            !
            ! Check below
            !
            nmu = z_index_uv_nd1(ip)    ! index of 1st uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = -1
                  wavemaker_angfac(iwm)    = max(sin(pi - phi(ip)), 0.0)
                  !
                  wavemaker_ndm(nok) = iwm
                  !
               endif
               !
            endif   
            !
            nmu = z_index_uv_nd2(ip)    ! index of 2nd uv neighbor to the right
            !
            if (nmu>0) then
               !
               iz = uv_index_z_nm(nmu)
               !
               if (kcs(iz) == 1) then
                  !
                  iwm = iwm + 1
                  !               
                  wavemaker_index_uv(iwm)  = nmu
                  wavemaker_index_nmi(iwm) = iz
                  wavemaker_index_nmb(iwm) = ip
                  wavemaker_idir(iwm)      = -1
                  wavemaker_angfac(iwm)    = max(sin(pi - phi(ip)), 0.0)
                  !
               endif
               !
            endif   
            !
         endif
      endif
   enddo
   !
   ! Set flags for kcuv points
   !
   do iwm = 1, wavemaker_nr_uv_points
      !
      ip = wavemaker_index_uv(iwm)
      kcuv(ip) = 4
      !
   enddo   
   !
   ! In case of forcing by boundary condition files, determine indices in bwv file
   !
   ! Read wave maker forcing points
   !
   wavemaker_nr_forcing_points  = 0     ! Total number of wave maker forcing points
   wavemaker_nr_forcing_timesteps = 0     ! Number of time steps in wave maker forcing time series
   wavemaker_itlast = 1 ! Last time point read in time series file 
   !
   wavemaker_timeseries = .false.
   !
   if (wavemaker_wfpfile(1:4) /= 'none') then
      !
      wavemaker_timeseries = .true.
      !
      write(logstr,*)'Reading wave conditions at wave makers ...'
      call write_log(logstr, 0)      
      !
      ! Locations
      !
      ok = check_file_exists(wavemaker_wfpfile, 'Wave maker wfp file', .true.)
      !
      open(500, file=trim(wavemaker_wfpfile))
      do while(.true.)
         read(500,*,iostat = stat)dummy
         if (stat<0) exit
         wavemaker_nr_forcing_points = wavemaker_nr_forcing_points + 1
      enddo
      rewind(500)
      allocate(wavemaker_xfp(wavemaker_nr_forcing_points))
      allocate(wavemaker_yfp(wavemaker_nr_forcing_points))
      do n = 1, wavemaker_nr_forcing_points
         read(500,*)wavemaker_xfp(n),wavemaker_yfp(n)
      enddo
      close(500)
      !
      ! Wave time series
      !
      ! First find times in whi file
      !
      ok = check_file_exists(wavemaker_wfpfile, 'Wave maker wfp file', .true.)
      !      
      open(500, file=trim(wavemaker_whifile))
      do while(.true.)
         read(500,*,iostat = stat)dummy
         if (stat<0) exit
         wavemaker_nr_forcing_timesteps = wavemaker_nr_forcing_timesteps + 1
      enddo
      close(500)
      !
      allocate(wavemaker_forcing_time(wavemaker_nr_forcing_timesteps))
      !
      ! Hm0 IG (significant wave height)
      ! Times in wti and wst files must be the same as in whi file!
      !
      open(500, file=trim(wavemaker_whifile))
      allocate(wavemaker_forcing_hm0_ig(wavemaker_nr_forcing_points, wavemaker_nr_forcing_timesteps))
      do itb = 1, wavemaker_nr_forcing_timesteps
         read(500,*)wavemaker_forcing_time(itb),(wavemaker_forcing_hm0_ig(ib, itb), ib = 1, wavemaker_nr_forcing_points)
      enddo
      close(500)
      !
      ! Tp IG (peak period)
      !
      ok = check_file_exists(wavemaker_wtifile, 'Wave maker wti file', .true.)
      !      
      open(500, file=trim(wavemaker_wtifile))
      allocate(wavemaker_forcing_tp_ig(wavemaker_nr_forcing_points, wavemaker_nr_forcing_timesteps))
      do itb = 1, wavemaker_nr_forcing_timesteps
         read(500,*)wavemaker_forcing_time(itb),(wavemaker_forcing_tp_ig(ib, itb), ib = 1, wavemaker_nr_forcing_points)
      enddo
      close(500)
      !
      ! Set-up
      !
      allocate(wavemaker_forcing_setup(wavemaker_nr_forcing_points, wavemaker_nr_forcing_timesteps))
      wavemaker_forcing_setup = 0.0
      if (wavemaker_wstfile(1:4) /= 'none') then
         !
         ok = check_file_exists(wavemaker_wstfile, 'Wave maker wst file', .true.)
         ! 
         open(500, file=trim(wavemaker_wstfile))
         do itb = 1, wavemaker_nr_forcing_timesteps
            read(500,*)wavemaker_forcing_time(itb),(wavemaker_forcing_setup(ib, itb), ib = 1, wavemaker_nr_forcing_points)
         enddo
         close(500)
      endif
      !
      if ((wavemaker_forcing_time(1) > (t0 + 1.0)) .or. (wavemaker_forcing_time(wavemaker_nr_forcing_timesteps) < (t1 - 1.0))) then
         ! 
         write(logstr,'(a)')' WARNING! Times in wave maker time series file do not cover entire simulation period !'
         call write_log(logstr, 0)         
         ! 
         if (wavemaker_forcing_time(1) > (t0 + 1.0)) then
            ! 
            write(logstr,'(a)')' WARNING! Adjusting first time in wave maker time series !'
            call write_log(logstr, 0)                                 
            !
            wavemaker_forcing_time(1) = t0 - 1.0
            !
         else
            ! 
            write(logstr,'(a)')' WARNING! Adjusting last time in wave maker time series !'
            call write_log(logstr, 0)                     
            !
            wavemaker_forcing_time(wavemaker_nr_forcing_timesteps) = t1 + 1.0
            !
         endif
         !
      endif   
      !
      ! Now determine weights and indices of wave maker forcing points for each uv point  
      !
      allocate(wavemaker_index_wmfp1(wavemaker_nr_uv_points))
      allocate(wavemaker_index_wmfp2(wavemaker_nr_uv_points))
      allocate(wavemaker_fac_wmfp(wavemaker_nr_uv_points))
      !   
      do iwm = 1, wavemaker_nr_uv_points
         !
         nmb    = wavemaker_index_nmb(iwm)
         !
         x = z_xz(nmb) ! x-coordinate of cell centre behind wave maker u/v point
         y = z_yz(nmb) ! x-coordinate of cell centre behind wave maker u/v point
         !
         if (wavemaker_nr_forcing_points>1) then ! More than one wave maker forcing point
            !
            dst1 = 1.0e10
            dst2 = 1.0e10
            ib1 = 0
            ib2 = 0
            !
            ! Loop through all water level boundary points
            !
            do ic = 1, wavemaker_nr_forcing_points
               !
               ! Compute distance of this point to grid boundary point
               !
               dst = sqrt((wavemaker_xfp(ic) - x)**2 + ( wavemaker_yfp(ic) - y)**2)
               !
               if (dst<dst1) then
                  !
                  ! Nearest point found
                  !
                  dst2 = dst1
                  ib2  = ib1
                  dst1 = dst
                  ib1  = ic
                  !
               elseif (dst<dst2) then
                  !
                  ! Second nearest point found
                  !
                  dst2 = dst
                  ib2  = ic
                  !
               endif
            enddo
            !
            wavemaker_index_wmfp1(iwm) = ib1
            wavemaker_index_wmfp2(iwm) = ib2
            wavemaker_fac_wmfp(iwm)    = dst2/(dst1 + dst2)
            !
         else
            !
            wavemaker_index_wmfp1(iwm) = 1
            wavemaker_index_wmfp2(iwm) = 1
            wavemaker_fac_wmfp(iwm)    = 1.0
            !
         endif
         !
      enddo
      !
   endif   
   !
   ! Infragravity frequencies
   !   
   allocate(wavemaker_freq_ig(wavemaker_nfreqs_ig))
   allocate(wavemaker_cost_ig(wavemaker_nfreqs_ig))
   allocate(wavemaker_phi_ig(wavemaker_nfreqs_ig))
   allocate(wavemaker_dphi_ig(wavemaker_nfreqs_ig))
   wavemaker_dfreq_ig = (wavemaker_freqmax_ig - wavemaker_freqmin_ig) / wavemaker_nfreqs_ig
   do ifreq = 1, wavemaker_nfreqs_ig
      wavemaker_freq_ig(ifreq) = wavemaker_freqmin_ig + ifreq * wavemaker_dfreq_ig - 0.5 * wavemaker_dfreq_ig
      call random_number(r)
      wavemaker_phi_ig(ifreq) = r * 2 * 3.1416
      wavemaker_dphi_ig(ifreq) = 1.0e-6 * 2 * 3.1416 / wavemaker_freq_ig(ifreq)
   enddo
   !
   if (wavemaker_hinc) then
      !
      allocate(wavemaker_freq_inc(wavemaker_nfreqs_inc))
      allocate(wavemaker_cost_inc(wavemaker_nfreqs_inc))
      allocate(wavemaker_phi_inc(wavemaker_nfreqs_inc))
      allocate(wavemaker_dphi_inc(wavemaker_nfreqs_inc))
      wavemaker_dfreq_inc = (wavemaker_freqmax_inc - wavemaker_freqmin_inc) / wavemaker_nfreqs_inc
      do ifreq = 1, wavemaker_nfreqs_inc
         wavemaker_freq_inc(ifreq) = wavemaker_freqmin_inc + ifreq * wavemaker_dfreq_inc - 0.5 * wavemaker_dfreq_inc
         call random_number(r)
         wavemaker_phi_inc(ifreq) = r * 2 * 3.1416
         wavemaker_dphi_inc(ifreq) = 1.0e-6 * 2 * 3.1416 / wavemaker_freq_inc(ifreq)
      enddo
      !
   endif   
   !
   end subroutine

   end module
