module sfincs_boundaries
   !
   ! CPU sibling of source/src/sfincs_boundaries_gpu.cuf.
   !
   ! Body is structured to mirror the GPU sibling so the two files diff
   ! cleanly: per-step interpolation goes through the shared helpers in
   ! sfincs_boundaries_io (interpolate_boundary_points,
   ! interpolate_boundary_zsb), boundary water levels flow through a
   ! per-step workbuf, and the final assignment loop is the same shape.
   ! The MPI_Bcast lines and the rank-local ownership filter that appear
   ! in the GPU sibling are absent here: the CPU build does not link MPI
   ! and is single-rank, so every grid boundary point is owned.
   !
   use sfincs_log
   use sfincs_error
   use sfincs_boundaries_io, only: io_read_boundary_data    => read_boundary_data, &
                                   io_find_boundary_indices => find_boundary_indices, &
                                   io_find_sfincs_cell      => find_sfincs_cell, &
                                   io_clean_line            => clean_line, &
                                   io_interpolate_boundary_points => interpolate_boundary_points, &
                                   io_interpolate_boundary_zsb    => interpolate_boundary_zsb
   !
   implicit none
   !
   ! Per-step host workbuf for the time-series-derived (kcs==2) boundary
   ! water levels. Sized to the global boundary count `size(nmindbnd)` on
   ! first call and reused thereafter.
   !
   real*4, allocatable, save, private :: zsb_global_workbuf(:)
   real*4, allocatable, save, private :: zsb0_global_workbuf(:)
   logical,             save, private :: bnd_first_call = .true.
   !
contains

   subroutine read_boundary_data()
   !
   ! Trampoline to sfincs_boundaries_io::read_boundary_data
   !
   implicit none
   !
   call io_read_boundary_data()
   !
   end subroutine


   subroutine find_boundary_indices()
   !
   ! Trampoline to sfincs_boundaries_io::find_boundary_indices
   !
   implicit none
   !
   call io_find_boundary_indices()
   !
   end subroutine


   subroutine update_boundary_points(t)
   !
   ! Time-interpolation of zs_bnd / zsi_bnd onto zst_bnd / zsit_bnd.
   ! CPU sibling: single-rank, no MPI; trampoline to the shared helper.
   !
   use sfincs_data, only: nbnd
   !
   implicit none
   !
   real*8, intent(in) :: t
   !
   if (nbnd == 0) return
   !
   call io_interpolate_boundary_points(t)
   !
   end subroutine


   subroutine update_boundary_conditions(t, dt)
   !
   ! Compute water level at boundary grid points.
   !
   ! Mirrors the GPU sibling's structural shape: a per-step workbuf holds
   ! the kcs==2 (water-level) boundary values produced by the shared
   ! helper; the assignment loop fans those out to zsb / zsb0 and fills
   ! the kcs==5 (downstream river) and kcs==6 (Neumann) entries from
   ! local model state. CPU build is single-rank, so every grid boundary
   ! point is rank-local.
   !
   use sfincs_data
   !
   implicit none
   !
   real*8 :: t
   real   :: dt
   !
   integer :: ib, nmb, ibdr
   real*8  :: zst
   !
   if (bnd_first_call) then
      allocate(zsb_global_workbuf(size(nmindbnd)))
      allocate(zsb0_global_workbuf(size(nmindbnd)))
      bnd_first_call = .false.
   endif
   !
   ! Compute kcs==2 boundary water levels into the workbuf.
   !
   call io_interpolate_boundary_zsb(t, zsb_global_workbuf, zsb0_global_workbuf)
   !
   ! Assignment loop: fan workbuf into zsb / zsb0 (kcs==2) and fill the
   ! kcs==5 / kcs==6 entries from local model state.
   !
   ! kcs = 1 : regular point
   ! kcs = 2 : water level boundary point (workbuf)
   ! kcs = 3 : outflow boundary point (set at initialization, no update)
   ! kcs = 4 : wave maker point
   ! kcs = 5 : river outflow point (dzs/dx = i)
   ! kcs = 6 : lateral (coastal) boundary point (Neumann dzs/dx = 0.0)
   !
   !$omp parallel private ( ib, nmb, zst, ibdr ) if(ngbnd > 10000)
   !$omp do schedule(dynamic, 64)
   do ib = 1, ngbnd
      !
      nmb = nmindbnd(ib)
      !
      if (kcs(nmb) == 2) then
         !
         zsb(ib)  = zsb_global_workbuf(ib)
         zsb0(ib) = zsb0_global_workbuf(ib)
         !
      elseif (kcs(nmb) == 5) then
         !
         ! Downstream river point: water level inside model adjusted by slope.
         !
         ibdr = index_bdr_gbp(ib)
         !
         zst = zs(index_zsi_bdr(ibdr)) + dzs_bdr(ibdr)
         !
         if (subgrid) then
            zst = max(zst, subgrid_z_zmin(nmb))
         else
            zst = max(zst, zb(nmb))
         endif
         !
         zsb(ib)  = zst
         zsb0(ib) = zst
         !
      elseif (kcs(nmb) == 6) then
         !
         ! Lateral coastal (Neumann) boundary: water level at boundary equals
         ! water level inside the model. zsb / zsb0 are not used here; flux
         ! at kcuv=6 points is solved in sfincs_momentum.
         !
         zs(nmb) = zs(nmi_gbp(ib))
         !
      endif
      !
   enddo
   !$omp end do
   !$omp end parallel
   !
   end subroutine


   subroutine update_boundary_fluxes(dt, t)
   !
   ! Update fluxes qx and qy at boundary points
   !
   use sfincs_data
   !
   implicit none
   !
   integer ib, nm, nmi, nmb, iuv, indb, ip
   real*4  hnmb, dt, zsnmi, zsnmb, zs0nmb, facrel
   real*4  factime, one_minus_factime
   real*8           :: t
   !
   real*4 ui, ub, dzuv, facint, zsuv, depthuv
   !
   factime = min(dt / btfilter, 1.0)
   one_minus_factime = 1.0 - factime
   facrel  = 1.0 - min(dt / btrelax, 1.0)
   !
   ! UV fluxes at boundaries
   !
   !$omp parallel private ( ib, indb, nmb, nmi, ip, zsnmi, zsnmb, zs0nmb, zsuv, depthuv, dzuv, iuv, facint, hnmb, ui, ub ) if(nkcuv2 > 10000)
   !$omp do schedule(dynamic, 64)
   do ib = 1, nkcuv2
      !
      indb   = ibkcuv2(ib)
      !
      nmb    = nmbkcuv2(ib)     ! nm index of kcs=2/3/5/6 boundary point
      !
      if (kcs(nmb) == 6) cycle  ! Lateral boundary point. Fluxes are computed in sfincs_momentum.f90.
      !
      nmi    = nmikcuv2(ib)     ! Index of kcs=1 point
      !
      ip     = index_kcuv2(ib)  ! Index in uv array of kcuv=2 velocity point
      !
      zsnmi  = zs(nmi)          ! total water level inside model
      zsnmb  = zsb(indb)        ! total water level at boundary
      zs0nmb = zsb0(indb)       ! average water level inside model (without waves)
      !
      if (bndtype == 1) then
         !
         ! Weakly reflective boundary (default)
         !
         if (subgrid) then
            !
            zsuv = max(zsnmb, zsnmi)
            !
            if (zsuv>=subgrid_uv_zmax(ip) - 1.0e-4) then
               !
               ! Entire cell is wet, no interpolation from table needed
               !
               depthuv  = subgrid_uv_havg_zmax(ip) + zsuv
               !
            elseif (zsuv>subgrid_uv_zmin(ip)) then
               !
               ! Interpolation required
               !
               dzuv    = (subgrid_uv_zmax(ip) - subgrid_uv_zmin(ip)) / (subgrid_nlevels - 1)
               iuv     = int((zsuv - subgrid_uv_zmin(ip))/dzuv) + 1
               facint  = (zsuv - (subgrid_uv_zmin(ip) + (iuv - 1)*dzuv) ) / dzuv
               depthuv = subgrid_uv_havg(iuv, ip) + (subgrid_uv_havg(iuv + 1, ip) - subgrid_uv_havg(iuv, ip))*facint
               !
            else
               !
               depthuv = 0.0
               !
            endif
            !
            hnmb   = max(depthuv, huthresh)
            zsnmb  = max(zsnmb,  subgrid_z_zmin(nmb))
            zs0nmb = max(zs0nmb, subgrid_z_zmin(nmb))
            !
         else
            !
            hnmb   = max(0.5 * (zsnmb + zsnmi) - zbuv(ip), huthresh)
            zsnmb  = max(zsnmb,  zb(nmb))
            zs0nmb = max(zs0nmb, zb(nmb))
            !
         endif
         !
         if (hnmb < huthresh + 1.0e-6 .or. kcuv(ip) == 3) then
            !
            ! Very shallow or also a structure point.
            !
            q(ip)      = 0.0
            uv(ip)     = 0.0
            uvmean(ib) = 0.0
            !
         else
            !
            ui = sqrt(g / hnmb) * (zsnmb - zs0nmb)
            ub = ibuvdir(ib) * (2 * ui - sqrt(g / hnmb) * (zsnmi - zs0nmb))
            !
            q(ip) = ub * hnmb + uvmean(ib)
            !
            ! Riemann
            !
            ! R = ubnd + 2 * sqrt(g * hnmb) ! from bca or bzs/buv
            !
            ! hnmi = hnmb + zsnmi - zsnmb
            !
            ! ub = R - 2 * sqrt(g * hnmi)
            !
            ! q(ip) = ub * hnmb
            !
            if (subgrid) then
               !
               ! Sub-grid
               !
               if (z_volume(nmi) <= 0.0) then
                  if (ibuvdir(ib) == 1) then
                     q(ip) = max(q(ip), 0.0) ! Nothing can flow out
                  else
                     q(ip) = min(q(ip), 0.0) ! Nothing can flow out
                  endif
               endif
               !
               if (zsnmb - subgrid_z_zmin(nmb) < huthresh) then
                  if (ibuvdir(ib) == 1) then
                     q(ip) = min(q(ip), 0.0) ! Nothing can flow in
                  else
                     q(ip) = max(q(ip), 0.0) ! Nothing can flow in
                  endif
               endif
               !
            else
               !
               ! Regular
               !
               if (zsnmi - zb(nmi) <= huthresh) then
                  if (ibuvdir(ib) == 1) then
                     q(ip) = max(q(ip), 0.0) ! Nothing can flow out
                  else
                     q(ip) = min(q(ip), 0.0) ! Nothing can flow out
                  endif
               endif
               !
               if (zsnmb - zb(nmb) < huthresh) then
                  if (ibuvdir(ib) == 1) then
                     q(ip) = min(q(ip), 0.0) ! Nothing can flow in
                  else
                     q(ip) = max(q(ip), 0.0) ! Nothing can flow in
                  endif
               endif
            endif
            !
            ! Limit velocities (this does not change fluxes, but may prevent advection term from exploding in the next time step)
            !
            uv(ip)  = max(min(q(ip) / hnmb, 4.0), -4.0)
            !
         endif
         !
         if (btfilter >= -1.0e-6) then
            !
            ! Added a little bit of relaxation in uvmean to avoid persistent jets shooting into the model
            ! Using: facrel = 1.0 - min(dt/btrelax, 1.0)
            ! Default: btrelax = 3600 s.
            !
            uvmean(ib) = factime * q(ip) + facrel * one_minus_factime * uvmean(ib)
            !
         else
            !
            uvmean(ib) = 0.0
            !
         endif
         !
         ! Set value on kcs=2 point to boundary condition
         !
         zs(nmb) = zsb(indb)
         !
         ! Store maximum water levels also on the boundary
         !
         if (store_maximum_waterlevel) then
            !
            ! Store when the maximum water level changed
            !
            if (store_t_zsmax) then
                if (zs(nmb) > zsmax(nmb)) then
                    t_zsmax(nmb) = t
                endif
            endif
            !
            zsmax(nmb) = max(zsmax(nmb), zs(nmb))
            !
         endif
         !
      endif
      !
   enddo
   !$omp end do
   !$omp end parallel
   !
   end subroutine



   subroutine update_boundaries(t, dt, tloop)
   !
   ! Update all boundary conditions
   !
   use sfincs_data
   !
   implicit none
   !
   integer  :: count0
   integer  :: count1
   integer  :: count_rate
   integer  :: count_max
   real     :: tloop
   !
   real*8           :: t
   real*4           :: dt
   !
   call system_clock(count0, count_rate, count_max)
   !
   if (boundaries_in_mask) then
      !
      if (nbnd > 0) then
         !
         ! Update boundary conditions at boundary points from time series
         !
         call update_boundary_points(t)
         !
      endif
      !
      ! In case of bathtub, we do not need to update boundary conditions at grid points or boundary fluxes,
      ! as these are not used in bathtub mode
      !
      if (.not. bathtub) then
         !
         ! Update boundary conditions at grid points (water levels)
         !
         call update_boundary_conditions(t, dt)
         !
         ! Update boundary fluxes
         !
         call update_boundary_fluxes(dt, t)
         !
      endif
      !
   endif
   !
   call system_clock(count1, count_rate, count_max)
   tloop = tloop + 1.0 * (count1 - count0) / count_rate
   !
   end subroutine
   !
   !
   !
   subroutine weighted_average(val1,val2,fac,iopt,val3)
   !
   implicit none
   !
   integer, intent(in)    :: iopt
   real*4,  intent(in)    :: val1
   real*4,  intent(in)    :: val2
   real*4,  intent(in)    :: fac
   real*4,  intent(out)   :: val3
   !
   real*4                 :: u1
   real*4                 :: v1
   real*4                 :: u2
   real*4                 :: v2
   real*4                 :: u
   real*4                 :: v
   !
   if (iopt==1) then
      !
      ! Regular
      !
      val3 = val1*fac  + val2*(1.0 - fac)
      !
   else
      !
      ! Angles (input must be in radians!)
      !
      u1 = cos(val1)
      v1 = sin(val1)
      u2 = cos(val2)
      v2 = sin(val2)
      !
      u = u1*fac  + u2*(1.0 - fac)
      v = v1*fac  + v2*(1.0 - fac)
      !
      val3 = atan2(v, u)
      !
   endif
   !
   end subroutine


   function find_sfincs_cell(n, m, iref) result (nm)
   !
   ! Trampoline to sfincs_boundaries_io::find_sfincs_cell
   !
   implicit none
   !
   integer, intent(in)  :: n
   integer, intent(in)  :: m
   integer, intent(in)  :: iref
   integer              :: nm
   !
   nm = io_find_sfincs_cell(n, m, iref)
   !
   end function

   function clean_line(s) result(out)
   !
   ! Trampoline to sfincs_boundaries_io::clean_line
   !
   character(len=*), intent(in) :: s
   character(len=len(s)) :: out
   !
   out = io_clean_line(s)
   !
   end function

end module
