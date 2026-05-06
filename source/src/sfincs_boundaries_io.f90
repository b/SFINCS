module sfincs_boundaries_io

   use sfincs_log
   use sfincs_error

contains

   subroutine read_boundary_data()
   !
   ! Reads bnd, bzs etc. files
   !
   use sfincs_ncinput
   use sfincs_data
   use quadtree
   use sfincs_date
   use astro
   !
   implicit none
   !
   integer n, itb, ib, stat, ifreq, iok, ibdr
   real*4  :: x_bdr_in, y_bdr_in, slope_bdr, distance_bdr
   logical :: ok
   !
   real*4 dummy,r
   !
   ! Astro
   !
   character(8), dimension(:), allocatable :: tidal_component_names
   integer, dimension(6) :: i_date_time
   character(len=256)    :: line
   integer               :: n_sets, n_components, ios
   integer               :: current_set, current_component
   character(len=8)      :: cname
   real*4                :: a, p
   logical               :: has_a0
   !
   ! Read water level boundaries
   !
   nbnd      = 0
   ntbnd     = 0
   itbndlast = 1
   !
   if (netbndbzsbzifile(1:4) /= 'none') then    ! FEWS compatible Netcdf water level time-series input
      !
      ok = check_file_exists(netbndbzsbzifile, 'Netcdf water level input netbndbzsbzi file', .true.)
      !
      call read_netcdf_boundary_data()
      !
      if ((t_bnd(1) > (t0 + 1.0)) .or. (t_bnd(ntbnd) < (t1 - 1.0))) then
         !
         write(logstr,'(a)')' WARNING! Times in boundary conditions file do not cover entire simulation period!'
         call write_log(logstr, 1)
         !
      endif
      !
   elseif (bndfile(1:4) /= 'none') then    ! Normal ascii input files
      !
      call write_log('Info    : reading water level boundaries', 0)
      !
      ok = check_file_exists(bndfile, 'Water level input locations bnd file', .true.)
      !
      open(500, file=trim(bndfile))
      do while(.true.)
         read(500,*,iostat = stat)dummy
         if (stat<0) exit
         nbnd = nbnd + 1
      enddo
      rewind(500)
      allocate(x_bnd(nbnd))
      allocate(y_bnd(nbnd))
      do n = 1, nbnd
         read(500,*)x_bnd(n),y_bnd(n)
      enddo
      close(500)
      !
      ! Read water level boundary conditions file
      !
      if (bzsfile(1:4) /= 'none') then
         !
         ok = check_file_exists(bzsfile, 'Boundary conditions bzs file', .true.)
         !
         open(500, file=trim(bzsfile))
         do while(.true.)
            read(500,*,iostat = stat)dummy
            if (stat<0) exit
            ntbnd = ntbnd + 1
         enddo
         rewind(500)
         !
         allocate(t_bnd(ntbnd))
         allocate(zs_bnd(nbnd,ntbnd))
         allocate(zst_bnd(nbnd))
         !
         do itb = 1, ntbnd
            read(500,*)t_bnd(itb),(zs_bnd(ib, itb), ib = 1, nbnd)
         enddo
         !
         close(500)
         !
      else
         !
         ! There is a bnd file, but no bzs file. Set all water levels at boundary to 0.0.
         ! This is possible when we force with a bca file.
         ! However, if there is no bca file, give a warning that the bzs file is missing.
         !
         if (bcafile(1:4) == 'none') then
            !
            write(logstr,'(a)')'Warning! Boundary points defined in bnd file without boundary conditions (bzs or bca file). Using water level of 0.0 m at these points.'
            call write_log(logstr, 1)
            !
         endif
         !
         ntbnd = 2
         !
         allocate(t_bnd(ntbnd))
         allocate(zs_bnd(nbnd,ntbnd))
         allocate(zst_bnd(nbnd))
         !
         t_bnd(1) = t0
         t_bnd(2) = t1
         zs_bnd   = 0.0
         zst_bnd  = 0.0
         !
      endif
      !
      if (bzifile(1:4) /= 'none') then
         !
         ! Incoming infragravity waves
         !
         allocate(zsi_bnd(nbnd,ntbnd))
         allocate(zsit_bnd(nbnd))
         !
         ok = check_file_exists(bzifile, 'Boundary infragravity time series bzi file', .true.)
         !
         open(500, file=trim(bzifile))
         do itb = 1, ntbnd
            read(500,*)dummy,(zsi_bnd(ib, itb), ib = 1, nbnd)
         enddo
         close(500)
         !
      endif
      !
      if ((t_bnd(1) > (t0 + 1.0)) .or. (t_bnd(ntbnd) < (t1 - 1.0))) then
         !
         write(logstr,'(a)')'Warning! Times in boundary conditions file do not cover entire simulation period !'
         call write_log(logstr, 1)
         !
         if (t_bnd(1) > (t0 + 1.0)) then
            !
            write(logstr,'(a)')'Warning! Adjusting first time in boundary conditions time series !'
            call write_log(logstr, 1)
            !
            t_bnd(1) = t0 - 1.0
            !
         else
            !
            write(logstr,'(a)')'Warning! Adjusting last time in boundary conditions time series !'
            call write_log(logstr, 1)
            !
            t_bnd(ntbnd) = t1 + 1.0
            !
         endif
         !
      endif
      !
   elseif (water_level_boundaries_in_mask) then
      !
      ! No bnd file provided, but there are open boundaries in the mask. Add one bnd point and set water levels to 0.0.
      !
      write(logstr,'(a)')'Warning! Boundary cells found in mask without boundary points from bnd file. Setting water level at 0.0 m at mask boundary cells.'
      call write_log(logstr, 1)
      !
      nbnd = 1
      allocate(x_bnd(nbnd))
      allocate(y_bnd(nbnd))
      x_bnd = 0.0
      y_bnd = 0.0
      !
      ntbnd = 2
      !
      allocate(t_bnd(ntbnd))
      allocate(zs_bnd(nbnd, ntbnd))
      allocate(zst_bnd(nbnd))
      !
      t_bnd(1) = t0
      t_bnd(2) = t1
      zs_bnd   = 0.0
      zst_bnd  = 0.0
      !
   endif
   !
   ! Check for 'weird' values
   !
   iok = 1
   !
   do ib = 1, nbnd
      do itb = 1, ntbnd
         !
         if (zs_bnd(ib, itb) < -99.0 .or. zs_bnd(ib, itb) > 990.0) then
            !
            iok = 0
            !
            zs_bnd(ib, itb) = 0.0
            !
         endif
         !
      enddo
   enddo
   !
   if (iok == 0) then
      !
      write(logstr,'(a)')'Warning! Very low, very high or NaN values found in boundary conditions file ! These have now been replaced with zeros. Please check !'
      call write_log(logstr, 1)
      !
   endif
   !
   ! Now the downstream river boundaries. No time series, just points, slope and direction
   !
   nbdr = 0
   !
   if (downstream_river_boundaries_in_mask) then
      !
      if (bdrfile(1:4) /= 'none') then
         !
         write(logstr,'(a)')'Info    : reading downstream river boundaries'
         call write_log(logstr, 0)
         !
         ok = check_file_exists(bdrfile, 'Downstream boundary points bdr file', .true.)
         !
         open(500, file=trim(bdrfile))
         do while(.true.)
            read(500,*,iostat = stat)dummy
            if (stat<0) exit
            nbdr = nbdr + 1
         enddo
         !
         rewind(500)
         !
         allocate(x_bdr(nbdr))
         allocate(y_bdr(nbdr))
         allocate(index_zsi_bdr(nbdr))
         allocate(dzs_bdr(nbdr))
         !
         do ibdr = 1, nbdr
            !
            read(500,*)x_bdr(ibdr), y_bdr(ibdr), x_bdr_in, y_bdr_in, slope_bdr, distance_bdr
            !
            ! Find grid cell that contains the internal point
            !
            index_zsi_bdr(ibdr) = find_quadtree_cell(x_bdr_in, y_bdr_in)
            !
            ! Water level difference between internal point and downstream boundary
            !
            if (distance_bdr < 0.0) then
               !
               ! Distance not provided. Take distance between two points in bdr file.
               !
               dzs_bdr(ibdr) = - slope_bdr * sqrt( (x_bdr_in - x_bdr(ibdr))**2 + (y_bdr_in - y_bdr(ibdr))**2 )
               !
            else
               !
               ! Distance is provided.
               !
               dzs_bdr(ibdr) = - slope_bdr * distance_bdr
               !
            endif
            !
         enddo
         !
         close(500)
         !
      else
         !
         ! This really should not happen
         !
         call stop_sfincs('Error ! Downstream river points found in mask, without boundary conditions (missing bdrfile in sfincs.inp) !', 1)
         !
      endif
      !
   else
      !
      if (bdrfile(1:4) /= 'none') then
         !
         write(logstr,'(a)')'Warning : Found bdr file in sfincs.inp, but no downstream river points in were found in the mask!'
         call write_log(logstr, 0)
         !
      endif
      !
   endif
   !
   ! If bca file is present (and use_bcafile = true, which is the default), read it
   !
   nr_tidal_components = 0
   !
   if (bcafile(1:4) /= 'none' .and. nbnd > 0 .and. use_bcafile) then
      !
      call write_log('Info    : reading tidal components', 0)
      !
      ok = check_file_exists(bcafile, 'Astro boundary conditions bca file', .true.)
      !
      !
      ! First pass: count number of sets and number of components in first set
      !
      ! NOTE 1 : The number of component sets in the bca file must match the number of points in the bnd file!
      ! NOTE 2 : The number of components in each set must be the same!
      !
      n_sets = 0
      n_components = 0
      has_a0 = .false.
      !
      open(500, file=trim(bcafile))
      !
      do
         !
         read(500, '(A)', iostat=ios) line
         line = clean_line(line)
         !
         if (ios /= 0) exit
         !
         if (trim(line) == '[forcing]' .or. trim(line) == '[Forcing]') then
            !
            n_sets = n_sets + 1
            !
         elseif (index(line, 'Quantity') > 0 .or. index(line, 'Unit') > 0 .or. index(line, 'Name') > 0 .or. index(line, 'Function') > 0) then
            !
            cycle  ! skip line
            !
         elseif (index(line, 'quantity') > 0 .or. index(line, 'unit') > 0 .or. index(line, 'name') > 0 .or. index(line, 'function') > 0) then
            !
            cycle  ! skip line
            !
         else
            !
            ! Try to read a data line
            !
            read(line, *, iostat=ios) cname, a, p
            !
            if (ios /= 0) cycle  ! not a data line
            !
            if (n_sets == 1) then  ! only count on first set
               !
               n_components = n_components + 1
               !
               ! Check if first component is A0
               !
               if (n_components == 1) then
                  !
                  if (cname(1:2) == 'a0' .or. cname(1:2) == 'A0') then
                     !
                     has_a0 = .true.
                     !
                  endif
                  !
               endif
               !
            endif
            !
         endif
         !
      enddo
      !
      ! Check whether n_sets is same as nbnd (otherwise give error)
      !
      if (n_sets /= nbnd) then
         !
         write(*,*)'ERROR! Number of astronomical tidal datasets in *.bca file ( ',n_sets,' ) does not match number of boundary points in *.bnd file (' ,nbnd,' )!'
         !
      endif
      !
      rewind(500)
      !
      if (.not. has_a0) then
         !
         ! Add 1 for A0
         !
         n_components = n_components + 1
         !
      endif
      !
      ! Allocate memory for names, amplitude, phase and frequency
      !
      nr_tidal_components = n_components
      !
      allocate(tidal_component_names(n_components))
      allocate(tidal_component_frequency(n_components))
      allocate(tidal_component_data(2, n_components, nbnd))
      !
      ! Initialize
      !
      tidal_component_data = 0.0
      tidal_component_names = ''
      !
      ! Second pass: read and parse data
      !
      current_set = 0
      current_component = 0
      !
      do
         read(500, '(A)', iostat=ios) line
         line = clean_line(line)
         !
         if (ios /= 0) exit
         !
         if (trim(line) == '[forcing]' .or. trim(line) == '[Forcing]') then
            !
            current_set = current_set + 1
            current_component = 0
            !
            if (.not. has_a0) then
               !
               current_component = 1
               tidal_component_names(1) = 'A0      '
               !
               ! Data has already be initialized at 0.0
               !
            endif
            !
         elseif (index(line, 'Quantity') > 0 .or. index(line, 'Unit') > 0 .or. index(line, 'Name') > 0 .or. index(line, 'Function') > 0) then
            !
            cycle  ! skip metadata
            !
         elseif (index(line, 'quantity') > 0 .or. index(line, 'unit') > 0 .or. index(line, 'name') > 0 .or. index(line, 'function') > 0) then
            !
            cycle  ! skip metadata
            !
         else
            !
            ! Try to read a data line
            !
            read(line, *, iostat=ios) cname, a, p
            !
            if (ios /= 0) cycle  ! not a data line
            !
            current_component = current_component + 1
            tidal_component_names(current_component) = cname
            tidal_component_data(1, current_component, current_set) = a
            tidal_component_data(2, current_component, current_set) = p
            !
         endif
         !
      enddo
      !
      close(500)
      !
      i_date_time = time_to_vector(0.0d0, trefstr)
      !
      !
      call update_nodal_factors(i_date_time, tidal_component_names, nr_tidal_components, nbnd, tidal_component_data, tidal_component_frequency)
      !
      tidal_component_frequency = tidal_component_frequency / 3600 ! Convert to rad/s
      !
   endif
   !
   end subroutine


   subroutine find_boundary_indices()
   !
   use sfincs_data
   !
   implicit none
   !
   ! For each grid boundary point (kcs=2, ) :
   !
   ! Determine indices and weights of boundary points
   ! For tide and surge, these are the indices and weights of the points in the bnd file
   !
   integer nm, m, n, nb, ib1, ib2, ib, ic, ibnd, ibdr, iref
   integer nmi
   !
   real x, y, dst1, dst2, dst
   !
   ! Check there are points from bnd file and/or bdr file and that kcs mask contains 2/3/5/6
   !
   if (ngbnd == 0) then
      !
      if (nbnd > 0 .or. nbdr > 0) then
         !
         write(logstr,'(a)')'Warning : no open boundary points found in mask!'
         call write_log(logstr, 1)
         !
      endif
      !
      return
      !
   endif
   !
   if (nbnd == 0 .and. nbdr == 0) then
      !
      !write(logstr,'(a)')'Warning : no open boundary points found in mask!'
      !call write_log(logstr, 1)
      !
      return
      !
   endif
   !
   ! Allocate boundary arrays
   !
   allocate(ind1_bnd_gbp(ngbnd))
   allocate(ind2_bnd_gbp(ngbnd))
   allocate(fac_bnd_gbp(ngbnd))
   !
   ind1_bnd_gbp = 0
   ind2_bnd_gbp = 0
   fac_bnd_gbp  = 0.0
   !
   if (downstream_river_boundaries_in_mask) then
      !
      ! There are downstream river boundaries
      !
      allocate(index_bdr_gbp(ngbnd))
      !
      index_bdr_gbp = 0
      !
   endif
   !
   if (neumann_boundaries_in_mask) then
      !
      ! There are Neumann boundaries, so we need nm indices of internal points
      !
      allocate(nmi_gbp(ngbnd))
      nmi_gbp = 0
      !
   endif
   !
   ! Find two closest boundary condition points for each boundary point
   !
   nb = 0
   !
   ! Loop through all grid boundary points
   !
   do ib = 1, ngbnd
      !
      nm = nmindbnd(ib)
      !
      x = z_xz(nm)
      y = z_yz(nm)
      !
      if (kcs(nm) == 2) then ! This cell is a water level boundary point
         !
         if (nbnd > 1) then
            !
            ! Multiple points in bnd file, so use distance-based weighting
            !
            dst1 = 1.0e10
            dst2 = 1.0e10
            ib1 = 0
            ib2 = 0
            !
            ! Loop through all water level boundary points in bnd file
            !
            do ibnd = 1, nbnd
               !
               ! Compute distance of this point to grid boundary point
               !
               dst = sqrt((x_bnd(ibnd) - x)**2 + (y_bnd(ibnd) - y)**2)
               !
               if (dst < dst1) then
                  !
                  ! Nearest point found
                  !
                  dst2 = dst1
                  ib2  = ib1
                  dst1 = dst
                  ib1  = ibnd
                  !
               elseif (dst < dst2) then
                  !
                  ! Second nearest point found
                  !
                  dst2 = dst
                  ib2  = ibnd
                  !
               endif
            enddo
            !
            ind1_bnd_gbp(ib) = ib1
            ind2_bnd_gbp(ib) = ib2
            fac_bnd_gbp(ib)  = dst2 / max(dst1 + dst2, 1.0e-9)
            !
         else
            !
            ind1_bnd_gbp(ib)  = 1
            ind2_bnd_gbp(ib)  = 1
            fac_bnd_gbp(ib)   = 1.0
            !
         endif
         !
      elseif (kcs(nm) == 5) then  ! This cell is a downstream river boundary point
         !
         ! We just look up nearest point in bdr file
         !
         dst1 = 1.0e10
         ib1 = 0
         !
         ! Loop through all points in bdr file
         !
         do ibdr = 1, nbdr
            !
            ! Compute distance of this point to grid boundary point
            !
            dst = sqrt((x_bdr(ibdr) - x)**2 + (y_bdr(ibdr) - y)**2)
            !
            if (dst < dst1) then
               !
               ! Nearest point found
               !
               dst1 = dst
               ib1  = ibdr
               !
            endif
            !
         enddo
         !
         index_bdr_gbp(ib) = ib1
         !
      elseif (kcs(nm) == 6) then  ! This cell is a Neumann boundary point
         !
         ! Indices of boundary cell
         !
         n = z_index_z_n(nm)
         m = z_index_z_m(nm)
         iref = z_flags_iref(nm)
         !
         ! Get index of internal point
         !
         nmi = find_sfincs_cell(n, m + 1, iref)
         if (nmi > 0) then
            if (kcs(nmi) == 1) then
                nmi_gbp(ib) = nmi
            else
                nmi = 0
            endif
         endif
         !
         nmi = find_sfincs_cell(n + 1, m, iref)
         if (nmi > 0) then
            if (kcs(nmi) == 1) then
                nmi_gbp(ib) = nmi
            else
                nmi = 0
            endif
         endif
         !
         nmi = find_sfincs_cell(n, m - 1, iref)
         if (nmi > 0) then
            if (kcs(nmi) == 1) then
                nmi_gbp(ib) = nmi
            else
                nmi = 0
            endif
         endif
         !
         nmi = find_sfincs_cell(n - 1, m, iref)
         if (nmi > 0) then
            if (kcs(nmi) == 1) then
                nmi_gbp(ib) = nmi
            else
                nmi = 0
            endif
         endif
         !
         if (nmi_gbp(ib) == 0) then
            !
            ! No active msk=1 point found in any of the neighbours, reset cell to inactive
            !
            kcs(nm) = 0
            !
            write(logstr,*)'Warning : Found a Neumann cell (msk=6) that does not have any valid neighbouring regular cell (msk=1)!'
            call write_log(logstr, 0)
            write(logstr,*)'Therefore cell set back to innactive (msk=0) for nm= ', nm
            call write_log(logstr, 0)
            !
         endif

         !
      endif
      !
   enddo
   !
   end subroutine


   function find_sfincs_cell(n, m, iref) result (nm)
   !
   ! Find nm index for cell n, m, iref
   !
   use sfincs_data
   use quadtree
   !
   implicit none
   !
   integer, intent(in)  :: n
   integer, intent(in)  :: m
   integer, intent(in)  :: iref
   integer              :: nm
   !
   integer :: nmq
   !
   nmq = find_quadtree_cell_by_index(n, m, iref)
   nm = index_sfincs_in_quadtree(nmq)
   !
   end function

   function clean_line(s) result(out)
   !
   character(len=*), intent(in) :: s
   character(len=len(s)) :: out
   integer :: i
   !
   out = trim(adjustl(s))
   i = index(out, char(13))
   if (i > 0) out = out(:i-1)
   !
   end function


   subroutine interpolate_boundary_points(t)
   !
   ! Time-interpolation of zs_bnd (and zsi_bnd when bzi is active) onto
   ! zst_bnd / zsit_bnd, for the nbnd points listed in the bnd file.
   !
   ! Shared body called by both sfincs_boundaries siblings: the GPU sibling
   ! invokes it on rank 0 only and then MPI_Bcasts the resulting zst_bnd /
   ! zsit_bnd to every rank; the CPU sibling calls it directly.
   !
   use sfincs_data
   !
   implicit none
   !
   real*8, intent(in) :: t
   !
   integer :: ib, itb, itb0, itb1, ic
   real*4  :: zstb, tbfac, tb
   !
   if (nbnd == 0) return
   !
   if (t_bnd(1) > (t - 1.0e-3)) then
      itb0 = 1
      itb1 = 1
      tb   = t_bnd(itb0)
   elseif (t_bnd(ntbnd) < (t + 1.0e-3)) then
      itb0 = ntbnd
      itb1 = ntbnd
      tb   = t_bnd(itb0)
   else
      do itb = itbndlast, ntbnd
         if (t_bnd(itb) > (t + 1.0e-6)) then
            itb0 = itb - 1
            itb1 = itb
            tb   = t
            itbndlast = itb - 1
            exit
         endif
      enddo
   endif
   !
   tbfac = (tb - t_bnd(itb0)) / max(t_bnd(itb1) - t_bnd(itb0), 1.0e-6)
   !
   do ib = 1, nbnd
      !
      zstb = zs_bnd(ib, itb0) + (zs_bnd(ib, itb1) - zs_bnd(ib, itb0))*tbfac
      !
      if (nr_tidal_components > 0) then
         do ic = 1, nr_tidal_components
            zstb = zstb + tidal_component_data(1, ic, ib) * cos(tidal_component_frequency(ic) * t - tidal_component_data(2, ic, ib))
         enddo
      endif
      !
      zst_bnd(ib) = zstb
      !
      if (bzifile(1:4) /= 'none') then
         zsit_bnd(ib) = zsi_bnd(ib, itb0) + (zsi_bnd(ib, itb1) - zsi_bnd(ib, itb0))*tbfac
      endif
      !
   enddo
   !
   end subroutine


   subroutine interpolate_boundary_zsb(t, zsb_out, zsb0_out)
   !
   ! Compute the per-grid-boundary-point water level workbuf for kcs==2
   ! (water-level boundary) cells from the time-interpolated zst_bnd /
   ! zsit_bnd plus the spatial weighting in ind1_bnd_gbp / ind2_bnd_gbp /
   ! fac_bnd_gbp. Outputs are sized ngbnd; only kcs==2 entries are written
   ! (kcs==5/6 are rank-local-state-dependent and filled by the caller).
   !
   ! Shared body called by both sfincs_boundaries siblings: GPU sibling
   ! invokes on rank 0, then MPI_Bcasts zsb_out / zsb0_out to every rank.
   !
   use sfincs_data
   !
   implicit none
   !
   real*8, intent(in)  :: t
   real*4, intent(out) :: zsb_out(:)
   real*4, intent(out) :: zsb0_out(:)
   !
   integer :: ib, nmb
   real*8  :: zst
   real*4  :: zsetup
   real*4  :: zig
   real*4  :: zs0act
   real*4  :: smfac
   real*4  :: zs0smooth
   logical :: has_bzi
   !
   has_bzi = (bzifile(1:4) /= 'none')
   !
   !$omp parallel private ( ib, nmb, zst, zsetup, zig, smfac, zs0act, zs0smooth ) if(ngbnd > 10000)
   !$omp do schedule(dynamic, 64)
   do ib = 1, ngbnd
      !
      nmb = nmindbnd(ib)
      !
      if (kcs(nmb) /= 2) cycle  ! kcs==5/6 are rank-local; caller fills.
      !
      if (nbnd > 1) then
         zst = zst_bnd(ind1_bnd_gbp(ib)) * fac_bnd_gbp(ib) + zst_bnd(ind2_bnd_gbp(ib)) * (1.0 - fac_bnd_gbp(ib))
      else
         zst = zst_bnd(1)
      endif
      !
      if (patmos .and. pavbnd > 1.0) then
         zst = zst + (pavbnd - patmb(ib)) / (rhow * 9.81)
      endif
      !
      zsetup = 0.0
      zig    = 0.0
      !
      if (has_bzi) then
         if (nbnd > 1) then
            zig = zsit_bnd(ind1_bnd_gbp(ib)) * fac_bnd_gbp(ib) + zsit_bnd(ind2_bnd_gbp(ib)) * (1.0 - fac_bnd_gbp(ib))
         else
            zig = zsit_bnd(1)
         endif
      endif
      !
      if (t < (tspinup - 1.0e-3)) then
         smfac = 1.0 - (t - t0) / (tspinup - t0)
         zs0act = zst + zsetup
         call weighted_average_io(zini, zs0act, smfac, 1, zs0smooth)
         zsb0_out(ib) = zs0smooth
         zs0act = zst + zsetup + zig
         call weighted_average_io(zini, zs0act, smfac, 1, zs0smooth)
         zsb_out(ib) = zs0smooth
      else
         zsb0_out(ib) = zst + zsetup
         zsb_out(ib)  = zst + zsetup + zig
      endif
      !
      if (subgrid) then
         zsb0_out(ib) = max(zsb0_out(ib), subgrid_z_zmin(nmb))
         zsb_out(ib)  = max(zsb_out(ib),  subgrid_z_zmin(nmb))
      else
         zsb0_out(ib) = max(zsb0_out(ib), zb(nmb))
         zsb_out(ib)  = max(zsb_out(ib),  zb(nmb))
      endif
      !
   enddo
   !$omp end do
   !$omp end parallel
   !
   end subroutine


   subroutine weighted_average_io(val1, val2, fac, iopt, val3)
   !
   ! Local copy of weighted_average so the io helper is self-contained
   ! (sibling modules call interpolate_boundary_zsb without depending on
   ! the sibling's own weighted_average).
   !
   implicit none
   !
   integer, intent(in)  :: iopt
   real*4,  intent(in)  :: val1
   real*4,  intent(in)  :: val2
   real*4,  intent(in)  :: fac
   real*4,  intent(out) :: val3
   !
   real*4 :: u1, v1, u2, v2, u, v
   !
   if (iopt == 1) then
      val3 = val1*fac + val2*(1.0 - fac)
   else
      u1 = cos(val1)
      v1 = sin(val1)
      u2 = cos(val2)
      v2 = sin(val2)
      u = u1*fac + u2*(1.0 - fac)
      v = v1*fac + v2*(1.0 - fac)
      val3 = atan2(v, u)
   endif
   !
   end subroutine

end module
