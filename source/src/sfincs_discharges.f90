module sfincs_discharges

   use sfincs_log
   use sfincs_error
   use sfincs_discharges_io, only: io_read_discharges => read_discharges

contains
   !
   subroutine read_discharges()
   !
   ! Trampoline to sfincs_discharges_io::read_discharges
   !
   implicit none
   !
   call io_read_discharges()
   !
   end subroutine
   !
   !
   !
   subroutine update_discharges(t, dt, tloop)
   !
   ! Update discharges
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
   real*4           :: qq
   real*4           :: qq0
   !
   real*4           :: dzds, frac, wdt, zsill, zmin, zmax, mng, hgate, dfrac, tcls, topen, tclose
   integer          :: idir
   !
   integer isrc, itsrc, idrn, jin, jout, nmin, nmout
   !
   call system_clock(count0, count_rate, count_max)
   !
   ! Compute instantaneous discharges from point sources
   !
   if (nsrc > 0) then
      do itsrc = itsrclast, ntsrc
         ! Find first point in time series large than t
         if (tsrc(itsrc) > t) then
            do isrc = 1, nsrc
               qtsrc(isrc) = qsrc(isrc, itsrc - 1) + (qsrc(isrc, itsrc) - qsrc(isrc, itsrc - 1)) * (t - tsrc(itsrc - 1)) / (tsrc(itsrc) - tsrc(itsrc - 1))
            enddo
            itsrclast = itsrc - 1
            exit
         endif
      enddo
      !
   endif
   !
   if (ndrn > 0) then
      !
      do idrn = 1, ndrn
         !
         jin  = nsrc + idrn * 2 - 1
         jout = nsrc + idrn * 2
         !
         nmin  = nmindsrc(jin)
         nmout = nmindsrc(jout)
         !
         if (nmin > 0 .and. nmout > 0) then
            !
            select case(drainage_type(idrn))
               !
               case(1)
                  !
                  ! Pump
                  !
                  qq = drainage_params(idrn, 1)
                  !
               case(2)
                  !
                  ! Culvert
                  !
                  if (zs(nmin)>zs(nmout)) then
                     !
                     qq  = drainage_params(idrn, 1) * sqrt(zs(nmin) - zs(nmout))
                     !
                  else
                     !
                     qq  = -drainage_params(idrn, 1) * sqrt(zs(nmout) - zs(nmin))
                     !
                  endif
                  !
               case(3)
                  !
                  ! Check valve (same as culvert, but only works in one direction)
                  !
                  if (zs(nmin) > zs(nmout)) then
                     !
                     qq = drainage_params(idrn, 1) * sqrt(zs(nmin) - zs(nmout))
                     !
                  else
                     !
                     qq = -drainage_params(idrn, 1) * sqrt(zs(nmout) - zs(nmin))
                     !
                  endif
                  !
                  ! Make sure it can only flow from intake to outfall point
                  !
                  qq = max(qq, 0.0)
                  !
               case(4)
                  !
                  ! Controlled gate. Gate opens when water level at intake point is between zmin and zmax.
                  !
                  wdt   = drainage_params(idrn, 1)                        ! width
                  zsill = drainage_params(idrn, 2)                        ! sill elevation
                  mng   = drainage_params(idrn, 3)                        ! Manning's n
                  zmin  = drainage_params(idrn, 4)                        ! min water level for open
                  zmax  = drainage_params(idrn, 5)                        ! max water level for open
                  tcls  = drainage_params(idrn, 6)                        ! closing time (seconds)
                  !
                  dzds = (zs(nmout) - zs(nmin)) / drainage_distance(idrn) ! water level slope
                  frac = drainage_fraction_open(idrn)                     ! fraction open (from previous time step)
                  hgate = max(max(zs(nmin), zs(nmout)) - zsill, 0.0)      ! water depth
                  dfrac = dt / tcls                                       ! change in fraction open per time step
                  !
                  qq0 = -qtsrc(jin) / (wdt * max(frac, 0.001))            ! discharge (in m2/s) from previous time step, excluding fraction open
                  !
                  ! Get status of gate
                  !
                  if (drainage_status(idrn) == 0) then
                     !
                     ! Gate fully closed
                     !
                     if (zs(nmin) > zmin .and. zs(nmin) < zmax) then
                        !
                        ! Water level is in allowable range, so need to open the gate
                        !
                        drainage_status(idrn) = 3
                        !
                        ! Lines below only work with Windows intel compiler, can be used for debugging
                        !
                        ! Actual discharges through drainage structure can always be checked if 'storeqdrain=1' in sfincs.inp
                        !
                        !write(logstr,'(a,i0,a,f0.1)')'INFO Gates - Opening structure ',idrn,' at t= ',t
                        !call write_log(logstr, 0)
                        !
                     endif
                     !
                  elseif (drainage_status(idrn) == 1) then
                     !
                     ! Gate fully open
                     !
                     if (zs(nmin) <= zmin .or. zs(nmin) >= zmax) then
                        !
                        ! Water level is NOT in allowable range, so need to close the gate
                        !
                        drainage_status(idrn) = 2
                        !
                        !write(logstr,'(a,i0,a,f0.1)')'INFO Gates - Closing structure ',idrn,' at t= ',t
                        !call write_log(logstr, 0)
                        !
                     endif
                     !
                  endif
                  !
                  ! Update fraction open
                  !
                  if (drainage_status(idrn) == 2) then
                     !
                     ! Gate is closing
                     !
                     frac = frac - dfrac
                     !
                     if (frac < 0.0) then
                        !
                        ! Gate is now fully closed
                        !
                        frac = 0.0
                        drainage_status(idrn) = 0
                        !
                     endif
                     !
                  elseif (drainage_status(idrn) == 3) then
                     !
                     ! Gate is opening
                     !
                     frac = frac + dfrac
                     !
                     if (frac > 1.0) then
                        !
                        ! Gate is now fully open
                        !
                        frac = 1.0
                        drainage_status(idrn) = 1
                        !
                     endif
                     !
                  endif
                  !
                  drainage_fraction_open(idrn) = frac
                  !
                  ! Use Bates et al. (2010) formulation to include inertia effects
                  !
                  qq = (qq0 - g * hgate * dzds * dt) / (1.0 + g * mng**2 * dt * abs(qq0) / hgate**(7.0 / 3.0))
                  !
                  ! Multiply with width and fraction open to get discharge in m3/s
                  !
                  qq = qq * wdt * frac
                  !
               case(5)
                  !
                  ! Controlled gate. Gate opens and closes at set user input times (only, and once), still using closing time.
                  !
                  wdt   = drainage_params(idrn, 1)                        ! width
                  zsill = drainage_params(idrn, 2)                        ! sill elevation
                  mng   = drainage_params(idrn, 3)                        ! Manning's n
                  tclose = drainage_params(idrn, 4)                       ! time wrt tref for closing gate
                  topen  = drainage_params(idrn, 5)                       ! time wrt tref for opening gate
                  tcls  = drainage_params(idrn, 6)                        ! closing time (seconds)
                  !
                  dzds = (zs(nmout) - zs(nmin)) / drainage_distance(idrn) ! water level slope
                  frac = drainage_fraction_open(idrn)                     ! fraction open (from previous time step)
                  hgate = max(max(zs(nmin), zs(nmout)) - zsill, 0.0)      ! water depth
                  dfrac = dt / tcls                                       ! change in fraction open per time step
                  !
                  qq0 = -qtsrc(jin) / (wdt * max(frac, 0.001))            ! discharge (in m2/s) from previous time step, excluding fraction open
                  !
                  ! Get status of gate
                  !
                  if (drainage_status(idrn) == 0) then
                     !
                     ! Gate fully closed
                     !
                     if (t >= topen) then
                        !
                        ! Time has passed 'topen', so need to open the gate
                        !
                        drainage_status(idrn) = 3
                        !
                        !write(logstr,'(a,i0,a,f0.1)')'INFO Gates - Opening structure ',idrn,' at t= ',t
                        !call write_log(logstr, 0)
                        !
                     endif
                     !
                  elseif (drainage_status(idrn) == 1) then
                     !
                     ! Gate fully open
                     !
                     if (t >= tclose .and. t < topen) then
                        !
                        ! Time has passed 'tclose', so need to close the gate
                        !
                        drainage_status(idrn) = 2
                        !
                        !write(logstr,'(a,i0,a,f0.1)')'INFO Gates - Closing structure ',idrn,' at t= ',t
                        !call write_log(logstr, 0)
                        !
                     endif
                     !
                  endif
                  !
                  ! Update fraction open
                  !
                  if (drainage_status(idrn) == 2) then
                     !
                     ! Gate is closing
                     !
                     frac = frac - dfrac
                     !
                     if (frac < 0.0) then
                        !
                        ! Gate is now fully closed
                        !
                        frac = 0.0
                        drainage_status(idrn) = 0
                        !
                     endif
                     !
                  elseif (drainage_status(idrn) == 3) then
                     !
                     ! Gate is opening
                     !
                     frac = frac + dfrac
                     !
                     if (frac > 1.0) then
                        !
                        ! Gate is now fully open
                        !
                        frac = 1.0
                        drainage_status(idrn) = 1
                        !
                     endif
                     !
                  endif
                  !
                  drainage_fraction_open(idrn) = frac
                  !
                  ! Use Bates et al. (2010) formulation to include inertia effects
                  !
                  qq = (qq0 - g * hgate * dzds * dt) / (1.0 + g * mng**2 * dt * abs(qq0) / hgate**(7.0 / 3.0))
                  !
                  ! Multiply with width and fraction open to get discharge in m3/s
                  !
                  qq = qq * wdt * frac
                  !
            end select
            !
            ! Add some relaxation
            ! structure_relax in seconds => gives ratio between new and old discharge (default 10s)
            !
            qq = 1.0 / (structure_relax / dt) * qq + (1.0 - (1.0 / (structure_relax / dt))) * -qtsrc(jin)
            !
            ! Limit discharge based on available volume in cell (regular or subgrid)
            !
            if (subgrid) then
               !
               if (qq > 0.0) then
                  qq = min(qq, max(z_volume(nmin), 0.0) / dt)
               else
                  qq = max(qq, -max(z_volume(nmout), 0.0) / dt)
               endif
               !
            else
               !
               if (qq > 0.0) then
                  qq = min(qq, max((zs(nmin) - zb(nmin)) * cell_area(z_flags_iref(nmin)), 0.0) / dt)
               else
                  qq = max(qq, -max((zs(nmout) - zb(nmout)) * cell_area(z_flags_iref(nmout)), 0.0) / dt)
               endif
               !
            endif
            !
            qtsrc(jin)  = -qq
            qtsrc(jout) = qq
            !
         endif
         !
      enddo
      !
   endif
   !
   call system_clock(count1, count_rate, count_max)
   tloop = tloop + 1.0 * (count1 - count0) / count_rate
   !
   end subroutine

end module
