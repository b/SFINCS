module sfincs_boundaries

   use sfincs_log
   use sfincs_error
   use sfincs_boundaries_io, only: io_read_boundary_data    => read_boundary_data, &
                                   io_find_boundary_indices => find_boundary_indices, &
                                   io_find_sfincs_cell      => find_sfincs_cell, &
                                   io_clean_line            => clean_line

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
   ! Update values at boundary points
   !
   use sfincs_data
   !
   implicit none
   !
   integer ib, itb, itb0, itb1, ic
   !
   real*8 t
   !
   real*4 zstb, tbfac, hs, tp, wd, tb
   !
   if (nbnd == 0) return ! no boundary points
   !
   ! Interpolate boundary conditions in time
   !
   if (t_bnd(1) > (t - 1.0e-3)) then  ! use first time in boundary conditions
      !
      itb0 = 1
      itb1 = 1
      tb   = t_bnd(itb0)
      !
   elseif (t_bnd(ntbnd) < (t + 1.0e-3)) then  ! use last time in boundary conditions
      !
      itb0 = ntbnd
      itb1 = ntbnd
      tb   = t_bnd(itb0)
      !
   else
      !
      do itb = itbndlast, ntbnd ! Loop in time
         if (t_bnd(itb) > (t + 1.0e-6)) then
            itb0 = itb - 1
            itb1 = itb
            tb   = t
            itbndlast = itb - 1
            exit
         endif
      enddo
      !
   endif
   !
   tbfac  = (tb - t_bnd(itb0)) / max(t_bnd(itb1) - t_bnd(itb0), 1.0e-6)
   !
   do ib = 1, nbnd ! Loop along boundary points
      !
      ! Tide and surge
      !
      zstb = zs_bnd(ib, itb0) + (zs_bnd(ib, itb1) - zs_bnd(ib, itb0))*tbfac
      !
      ! Add astronomical tides
      !
      if (nr_tidal_components > 0) then
         !
         do ic = 1, nr_tidal_components
            !
            zstb = zstb + tidal_component_data(1, ic, ib) * cos(tidal_component_frequency(ic) * t - tidal_component_data(2, ic, ib))
            !
         enddo
         !
      endif
      !
      zst_bnd(ib) = zstb
      !
      if (bzifile(1:4) /= 'none') then
         !
         ! Incoming infragravity waves
         !
         zsit_bnd(ib) = zsi_bnd(ib, itb0) + (zsi_bnd(ib, itb1) - zsi_bnd(ib, itb0))*tbfac
         !
      endif
       !
   enddo
   !
   end subroutine


   subroutine update_boundary_conditions(t, dt)
   !
   ! Update water level at boundary grid points
   !
   use sfincs_data
   !
   implicit none
   !
   integer ib, nmb, ibdr
   !
   real*8                            :: t
   real                              :: dt
   !
   real*8 zst
   real*4 zsetup
   real*4 zig
   real*4 zs0act
   real*4 smfac
   real*4 zs0smooth
   logical :: has_bzi
   !
   has_bzi = (bzifile(1:4) /= 'none')
   !
   ! Set water level in all boundary points on grid
   ! This loop is all done on the CPU
   !
   !$omp parallel private ( ib, nmb, zst, zsetup, zig, smfac, zs0act, ibdr, zs0smooth ) if(ngbnd > 10000)
   !$omp do schedule(dynamic, 64)
   do ib = 1, ngbnd
      !
      nmb = nmindbnd(ib)
      !
      ! kcs = 1 : regular point
      ! kcs = 2 : water level boundary point
      ! kcs = 3 : outflow boundary point (water levels were set at initialization, so no need to update them here)
      ! kcs = 4 : wave maker point
      ! kcs = 5 : river outflow point (dzs/dx = i)
      ! kcs = 6 : lateral (coastal) boundary point (Neumann dzs/dx = 0.0)
      !
      if (kcs(nmb) == 2) then
         !
         ! Regular water level boundary point
         !
         ! Get water levels (surge + tide) from time series boundary conditions
         !
         if (nbnd > 1) then
            !
            ! Interpolation of nearby points
            !
            zst   = zst_bnd(ind1_bnd_gbp(ib)) * fac_bnd_gbp(ib) + zst_bnd(ind2_bnd_gbp(ib)) * (1.0 - fac_bnd_gbp(ib))
            !
         else
            !
            ! Just use the value of the one boundary point
            !
            zst   = zst_bnd(1)
            !
         endif
         !
         if (patmos .and. pavbnd>1.0) then
            !
            ! Barometric pressure correction
            !
            zst = zst + (pavbnd - patmb(ib)) / (rhow * 9.81)
            !
         endif
         !
         zsetup = 0.0
         zig    = 0.0
         !
         ! Incoming IG waves from file (this will overrule IG signal computed before)
         !
         if (has_bzi) then
            !
            if (nbnd > 1) then
               !
               ! Interpolation of nearby points
               !
               zig = zsit_bnd(ind1_bnd_gbp(ib)) * fac_bnd_gbp(ib)  + zsit_bnd(ind2_bnd_gbp(ib)) * (1.0 - fac_bnd_gbp(ib))
               !
            else
               !
               ! Just use the value of the one boundary point
               !
               zig = zsit_bnd(1)
               !
            endif
            !
         endif
         !
         if (t < (tspinup - 1.0e-3)) then
            !
            smfac = 1.0 - (t - t0) / (tspinup - t0)
            !
            zs0act = zst + zsetup
            call weighted_average(zini, zs0act, smfac, 1, zs0smooth)
            zsb0(ib) = zs0smooth           ! Still water level at kcs=2 point
            !
            zs0act = zst + zsetup + zig
            call weighted_average(zini, zs0act, smfac, 1, zs0smooth)
            zsb(ib) = zs0smooth            ! Total water level at kcs=2 point
            !
         else
            !
            zsb0(ib) = zst + zsetup        ! Still water level at kcs=2 point
            zsb(ib)  = zst + zsetup + zig  ! Total water level at kcs=2 point
            !
         endif
         !
         if (subgrid) then                  ! Check on waterlevels minimally equal to z_zmin
            zsb0(ib) = max(zsb0(ib), subgrid_z_zmin(nmb))
            zsb(ib)  = max(zsb(ib),  subgrid_z_zmin(nmb))
         else                               ! Check on waterlevels minimally equal to zb
            zsb0(ib) = max(zsb0(ib), zb(nmb))
            zsb(ib)  = max(zsb(ib),  zb(nmb))
         endif
         !
      elseif (kcs(nmb) == 5) then
         !
         ! Downstream river point
         !
         ! Get water levels from inside model, and adjust for slope.
         !
         ibdr = index_bdr_gbp(ib) ! index of the downstream boundary point that forces this grid boundary point ib
         !
         zst = zs(index_zsi_bdr(ibdr)) + dzs_bdr(ibdr) ! internal water level minus slope * distance
         !
         ! Make sure water level is not below bed level
         !
         if (subgrid) then
            !
            zst = max(zst, subgrid_z_zmin(nmb))
            !
         else
            !
            zst = max(zst, zb(nmb))
            !
         endif
         !
         zsb(ib) = zst
         zsb0(ib) = zst
         !
      elseif (kcs(nmb) == 6) then
         !
         ! Lateral coastal (Neumann) boundary
         !
         ! Set water level at boundary point equal to water level inside model.
         ! No need to set zsb and zsb0, as flux for this type of boundary is solved in sfincs_momentum.f90.
         ! Lateral boundary u/v points have kcuv=6. They are skipped in update_boundary_fluxes.
         !
         ! TODO: OPENACC!!!!
         !
         zs(nmb) = zs(nmi_gbp(ib)) ! nm index of internal point. Technically there can be more than one internal point. This always uses the last point that was found.
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
