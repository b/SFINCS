module sfincs_meteo

   use sfincs_meteo_io, only: read_meteo_data, &
                              update_spiderweb_data, &
                              update_amuv_data, &
                              update_amp_data, &
                              update_ampr_data

contains

   subroutine update_meteo_forcing(t, dt, tloop)
   !
   ! Update wind stresses and precipitation (this happens every time step)
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
   real*8                           :: t
   real*4                           :: dt
   real*4                           :: twfact
   real*4                           :: onemintwfact
   real*4                           :: smfac
   real*4                           :: oneminsmfac
   integer                          :: nm, ib
   !
   call system_clock(count0, count_rate, count_max)
   !
   if (meteo3d) then
      !
      twfact  = (t - meteo_t0) / (meteo_t1 - meteo_t0)
      onemintwfact = 1.0 - twfact
      !
      !$omp parallel &
      !$omp private ( nm )
      !$omp do
      do nm = 1, np
         !
         if (wind) then
            !
            tauwu(nm) = tauwu0(nm) * onemintwfact + tauwu1(nm) * twfact
            tauwv(nm) = tauwv0(nm) * onemintwfact + tauwv1(nm) * twfact
            !
            if (store_wind) then
               !
               windu(nm) = windu0(nm) * onemintwfact + windu1(nm) * twfact
               windv(nm) = windv0(nm) * onemintwfact + windv1(nm) * twfact
               !
               if (store_wind_max) then
                  windmax(nm) = max(windmax(nm), sqrt(windu(nm)**2 + windv(nm)**2))
               endif
               !
            endif
            !
         endif
         !
         if (patmos) then
            !
            patm(nm) = patm0(nm) * onemintwfact  + patm1(nm) * twfact  ! atmospheric pressure (Pa)
            !
         endif
         !
         if (precip) then
            !
            prcp(nm) = prcp0(nm) * onemintwfact  + prcp1(nm) * twfact  ! rainfall in m/s !!!
            !
            ! Don't allow negative prcp (e.g. hardfixing infiltration/evaporation on model when forcing effective rainfall) when there's no water in the cell (same as check for constant infiltration)
            !
            if (prcp(nm) < 0.0) then
               !
               ! No effective infiltration if there is no water
               !
               if (subgrid) then
                  if (z_volume(nm) <= 0.0) then
                     prcp(nm) = 0.0
                  endif
               else
                  if (zs(nm) <= zb(nm)) then
                     prcp(nm) = 0.0
                  endif
               endif
               !
            endif
            !
            netprcp(nm) = prcp(nm)
            !
            if (store_cumulative_precipitation) then
               !
               cumprcp(nm) = cumprcp(nm) + prcp(nm) * dt
               !
            endif
            !
         endif
         !
      enddo
      !$omp end do
      !$omp end parallel
      !
      ! Apply spin-up factor
      !
      if (t < (tspinup - 1.0e-3) .and. spinup_meteo) then
         !
         smfac = (t - t0) / (tspinup - t0)
         oneminsmfac = 1.0 - smfac
         !
         !$omp parallel &
         !$omp private ( nm )
         !$omp do
         do nm = 1, np
            !
            if (wind) then
               tauwu(nm) = tauwu(nm) * smfac
               tauwv(nm) = tauwv(nm) * smfac
            endif
            !
            if (patmos) then
               patm(nm)  = patm(nm) * smfac + gapres * oneminsmfac
            endif
            !
            if (precip) then
               !
               netprcp(nm) = netprcp(nm) * smfac
               !
               ! Don't allow negative netprcp during spinup (e.g. hardfixing infiltration/evaporation on model when forcing effective rainfall) when there's no water in the cell (same as check for constant infiltration)
               !
               if (netprcp(nm) < 0.0) then
                  !
                  ! No effective infiltration if there is no water
                  !
                  if (subgrid) then
                     if (z_volume(nm) <= 0.0) then
                        netprcp(nm) = 0.0
                     endif
                  else
                     if (zs(nm) <= zb(nm)) then
                        netprcp(nm) = 0.0
                     endif
                  endif
                  !
               endif
            endif
            !
         enddo
         !$omp end do
         !$omp end parallel
         !
      endif
      !
      if (patmos .and. pavbnd > 0.0) then
         !
         ! Update atmospheric pressure at boundary points (patmb)
         !
         do ib = 1, ngbnd
            !
            patmb(ib) = patm(nmindbnd(ib))
            !
         enddo
         !
         ! patmb is used at boundary points in the CPU part of update_boundary_conditions (should try to make this faster)
         !
      endif
      !
   endif
   !
   ! Wind from time series
   !
   if (wndfile(1:4) /= 'none') then
      !
      ! Wind from time series
      !
      call update_wind_forcing_from_timeseries(t)
      !
   endif
   !
   ! Rainfall from time series
   !
   if (prcpfile(1:4) /= 'none') then
      !
      call update_precipitation_from_timeseries(t, dt)
      !
   endif
   !
   call system_clock(count1, count_rate, count_max)
   tloop = tloop + 1.0 * (count1 - count0) / count_rate
   !
   end subroutine


   subroutine update_wind_forcing_from_timeseries(t)
   !
   ! Update values at boundary points
   !
   use sfincs_data
   !
   implicit none
   !
   integer itw, nm
   !
   real*8                           :: t, twu, twv
   !
   real*4 cd, vmag, vdir, dr0, dr1, twfac
   !
   do itw = itwndlast, ntwnd ! Loop in time
      !
      if (twnd(itw)>t) then
         !
         twfac  = (t - twnd(itw - 1)) / (twnd(itw) - twnd(itw - 1))
         !
         vmag = wndmag(itw - 1) * (1.0 - twfac) + wndmag(itw) * twfac
         dr0  = modulo(wnddir(itw - 1), 2 * pi)
         dr1  = modulo(wnddir(itw ),    2 * pi)
         if (dr1 > dr0 + pi) then
             dr0 = dr0 + 2 * pi
         elseif (dr0 > dr1 + pi) then
             dr1 = dr1 + 2 * pi
         endif
         vdir = dr0 * (1.0 - twfac) + dr1 * twfac
         !
         cd = cdval(int(vmag * 10) + 1)
         !
         twu = vmag**2 * cos(vdir) * rhoa * cd / rhow
         twv = vmag**2 * sin(vdir) * rhoa * cd / rhow
         !
         !$omp parallel &
         !$omp private ( nm ) &
         !$omp shared ( tauwu,tauwv )
         !$omp do
         do nm = 1, np
            tauwu(nm) = twu
            tauwv(nm) = twv
         enddo
         !$omp end do
         !$omp end parallel
         !
         itwndlast = itw - 1
         !
         if (store_wind) then
             !
             windu = vmag * cos(vdir)
             windv = vmag * sin(vdir)
             !
         endif
         !
         exit
         !
       endif
   enddo
   !
   end subroutine

   subroutine update_precipitation_from_timeseries(t, dt)
   !
   ! Update values at boundary points
   !
   use sfincs_data
   !
   implicit none
   !
   integer itp, nm
   !
   real*8  :: t
   real*4  :: dt
   real*4  :: twfac
   real*4  :: ptmp
   !
   do itp = itprcplast, ntprcp ! Loop in time
      if (tprcpt(itp) > t) then
         exit
      endif
   enddo
   !
   itp = max(min(itp, ntprcp), 1)
   !
   twfac  = (t - tprcpt(itp - 1)) / (tprcpt(itp) - tprcpt(itp - 1))
   !
   ptmp = (tprcpv(itp - 1) * (1.0 - twfac) + tprcpv(itp) * twfac) / (1000 * 3600) ! rain in m/s
   !
   !$omp parallel &
   !$omp private ( nm )
   !$omp do
   do nm = 1, np
      !
      prcp(nm)    = ptmp
      netprcp(nm) = ptmp
      !
      if (store_cumulative_precipitation) then
         cumprcp(nm) = cumprcp(nm) + ptmp * dt
      endif
      !
   enddo
   !$omp end do
   !$omp end parallel
   !
   itprcplast = itp - 1
   !
   end subroutine


   subroutine update_meteo_fields(t, tloop)
   !
   ! Update values at boundary points
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
   integer  :: nm
   !
   real*8   :: t
   !
   call system_clock(count0, count_rate, count_max)
   !
   if (amufile(1:4) /= 'none' .or. netamuamvfile(1:4) /= 'none') then
      !
      call update_amuv_data()
      !
   endif
   !
   if ((ampfile(1:4) /= 'none' .or. netampfile(1:4) /= 'none') .and. patmos) then
      !
      call update_amp_data()
      !
   endif
   !
   if (amprfile(1:4) /= 'none' .or. netamprfile(1:4) /= 'none') then
      !
      call update_ampr_data()
      !
   endif
   !
   if (spwfile(1:4) /= 'none' .or. netspwfile(1:4) /= 'none') then
      !
      call update_spiderweb_data()
      !
   endif
   !
   call system_clock(count1, count_rate, count_max)
   tloop = tloop + 1.0*(count1 - count0)/count_rate
   !
   end subroutine

end module
