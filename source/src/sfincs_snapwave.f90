module sfincs_snapwave
   !
   use sfincs_log
   use sfincs_error
   use sfincs_snapwave_init
   use sfincs_snapwave_io
   !
   implicit none
   !
contains
   !
   subroutine update_wave_field(t, tloop)
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
   real*4   :: u10, u10dir
   !
   real*4,    dimension(:), allocatable       :: fwx0
   real*4,    dimension(:), allocatable       :: fwy0
   real*4,    dimension(:), allocatable       :: dw0
   real*4,    dimension(:), allocatable       :: df0
   real*4,    dimension(:), allocatable       :: dwig0
   real*4,    dimension(:), allocatable       :: dfig0
   real*4,    dimension(:), allocatable       :: cg0
   !real*4,    dimension(:), allocatable       :: qb0
   real*4,    dimension(:), allocatable       :: beta0
   real*4,    dimension(:), allocatable       :: srcig0
   real*4,    dimension(:), allocatable       :: alphaig0
   integer   :: ip, nm, nmu, idir
   real*8    :: t
   !
   call system_clock(count0, count_rate, count_max)
   !
   allocate(fwx0(np))
   allocate(fwy0(np))
   allocate(dw0(np))
   allocate(df0(np))
   allocate(dwig0(np))
   allocate(dfig0(np))
   allocate(cg0(np))
   !allocate(qb0(np))
   allocate(beta0(np))
   allocate(srcig0(np))
   allocate(alphaig0(np))
   !
   fwx0 = 0.0
   fwy0 = 0.0
   dw0 = 0.0
   df0 = 0.0
   dwig0 = 0.0
   dfig0 = 0.0
   cg0 = 0.0
   !qb0 = 0.0
   beta0 = 0.0
   srcig0 = 0.0
   alphaig0 = 0.0
   !
   ! Determine SnapWave water depth
   !
   do nm = 1, snapwave_no_nodes
      !
      ip = index_sfincs_in_snapwave(nm) ! matching index in SFINCS mesh
      !
      if (ip > 0) then
         !
         ! A matching SFINCS point is found
         !

         if (wavemaker) then
            !
            snapwave_depth(nm) = max(zsm(ip) - snapwave_z(nm), 0.00001)
            !
         else
            !
            snapwave_depth(nm) = max(zs(ip) - snapwave_z(nm), 0.00001)
            !
         endif
         !
      else
         !
         ! Use 0.0 water level
         !
         snapwave_depth(nm) = max(0.0 - snapwave_z(nm), 0.00001)
         !
      endif
      !
   enddo
   !
   ! Determine SnapWave wind
   !
   if (wind) then ! =We have wind inputs given to SFINCS
      !
      if (snapwavewind) then ! =We have windgrowth in SnapWave turned on
          !
          do nm = 1, snapwave_no_nodes
             !
             ip = index_sfincs_in_snapwave(nm) ! matching index in SFINCS mesh
             !
             if (ip>0) then
                !
                ! A matching SFINCS point is found
                !
                ! Convert to umag & dir, as in ncoutput_update_his:
                !
                u10 = sqrt(windu(ip)**2 + windv(ip)**2)
                !
                u10dir = atan2(windv(ip), windu(ip))*180/pi
                !
	            if (u10dir<0.0) u10dir = u10dir + 360.0
                if (u10dir>360.0) u10dir = u10dir - 360.0
                !
                snapwave_u10(nm) = max(u10, 0.0)
                snapwave_u10dir(nm) = u10dir / 180.0 * pi ! from nautical coming from in degrees to cartesian going to in radians
                !
             else
                !
                ! Use 0.0 wind speed and direction
                !
                snapwave_u10(nm) = 0.0
                snapwave_u10dir(nm) = 0.0
                !
             endif
             !
          enddo
          !
      endif
      !
   endif
   !
   call compute_snapwave(t)
   !
   do nm = 1, np
      !
      ip = index_snapwave_in_sfincs(nm) ! matching index in SFINCS mesh
      !
      if (ip>0) then
         !
         hm0(nm)    = snapwave_H(ip)
         hm0_ig(nm) = snapwave_H_ig(ip)
         sw_tp(nm)    = snapwave_Tp(ip)
         sw_tp_ig(nm) = snapwave_Tp_ig(ip)
         fwx0(nm)   = snapwave_Fx(ip)
         fwy0(nm)   = snapwave_Fy(ip)
         dw0(nm)    = snapwave_Dw(ip)
         df0(nm)    = snapwave_Df(ip)
         dwig0(nm)  = snapwave_Dwig(ip)
         dfig0(nm)  = snapwave_Dfig(ip)
         cg0(nm)    = snapwave_cg(ip)
         !qb0(nm)    = snapwave_Qb(ip)
         beta0(nm)  = snapwave_beta(ip)
         srcig0(nm) = snapwave_srcig(ip)
         alphaig0(nm) = snapwave_alphaig(ip)
         if (store_wave_direction) then
            mean_wave_direction(nm) = snapwave_mean_direction(ip)
            wave_directional_spreading(nm) = snapwave_directional_spreading(ip)*180/pi
         endif
         !
      else
         !
         ! SnapWave point outside active SFINCS domain
         !
         hm0(nm)    = 0.0
         hm0_ig(nm) = 0.0
         sw_tp(nm)  = 0.0
         sw_tp_ig(nm) = 0.0
         fwx0(nm)   = 0.0
         fwy0(nm)   = 0.0
         dw0(nm)    = 0.0
         df0(nm)    = 0.0
         dwig0(nm)  = 0.0
         dfig0(nm)  = 0.0
         cg0(nm)    = 0.0
         !qb0(nm)    = 0.0
         beta0(nm)  = 0.0
         srcig0(nm) = 0.0
         alphaig0(nm) = 0.0
         if (store_wave_direction) then
            mean_wave_direction(nm)        = 0.0
            wave_directional_spreading(nm) = 0.0
         endif
         !
      endif
      !
      if (store_wave_forces) then
         !
         fwx(nm)        = fwx0(nm)
         fwy(nm)        = fwy0(nm)
         dw(nm)         = dw0(nm)
         df(nm)         = df0(nm)
         dwig(nm)       = dwig0(nm)
         dfig(nm)       = dfig0(nm)
         cg(nm)         = cg0(nm)
         !qb(nm)         = qb0(nm)
         betamean(nm)   = beta0(nm)
         srcig(nm)      = srcig0(nm)
         alphaig(nm)    = alphaig0(nm)
         !
      endif
      !
   enddo
   !
   hm0 = hm0 * sqrt(2.0)
   hm0_ig = hm0_ig * sqrt(2.0)
   !
   do ip = 1, npuv
      !
      nm   = uv_index_z_nm(ip)
      nmu  = uv_index_z_nmu(ip)
      idir = uv_flags_dir(ip) ! 0 is u, 1 is v
      !
      ! Should do better averaging for uv points that go from fine to coarse
      !
      if (idir == 0) then
         !
         ! U point
         !
         fwuv(ip) = waveforces_factor * (0.5 * (cosrot * fwx0(nm) + sinrot * fwy0(nm)) + 0.5 * ( cosrot * fwx0(nmu) + sinrot * fwy0(nmu))) / rhow
         ! waveforces_factor = 1.0 by default, but can be set to 0 to avoid double counting incident setup if wavemaker_hinc true
      else
         !
         ! V point
         !
         fwuv(ip) = waveforces_factor * (0.5 * (-sinrot * fwx0(nm) + cosrot * fwy0(nm)) + 0.5 * (-sinrot * fwx0(nmu) + cosrot * fwy0(nmu))) / rhow
         !
      endif
      !
   enddo
   !
   call system_clock(count1, count_rate, count_max)
   tloop = tloop + 1.0*(count1 - count0)/count_rate
   !
   end subroutine


   subroutine compute_snapwave(t)
   !
   use snapwave_data
   use snapwave_solver
   use snapwave_boundaries
   !
   real*8    :: t
   integer   :: k
   !
   depth = snapwave_depth
   !
   zb = snapwave_z
   !
   u10 = snapwave_u10
   u10dir = snapwave_u10dir
   !
   ! TL: we use depth now in boundary conditions for Herbers bc determination of Hm0ig, in this order we use updated values of depth through SFINCS
   !
   call update_boundary_conditions(t) ! SnapWave boundary conditions
   !
   call compute_wave_field()
   !
   snapwave_H                     = H
   snapwave_H_ig                  = H_ig
   snapwave_Tp                    = Tp
   snapwave_Tp_ig                 = Tp_ig
   snapwave_mean_direction        = modulo(270.0 - thetam * 180 / pi + 360.0, 360.0)
   snapwave_directional_spreading = thetam  ! TL: CORRECT? > is not spreading but mean direction?
   snapwave_Dw                    = Dw
   snapwave_Df                    = Df
   snapwave_Dwig                  = Dw_ig
   snapwave_Dfig                  = Df_ig
   snapwave_cg                    = cg
   snapwave_beta                  = beta
   snapwave_srcig                 = srcig
   snapwave_alphaig               = alphaig
   !
   ! Convert wave force to correct unit [Dw/C] as expected by SFINCS, assumed to be piecewise (seems to work)
   snapwave_Fx                    = Fx * rho * depth
   snapwave_Fy                    = Fy * rho * depth
   !
   ! Loop over points and set Tp, cg, direction, spreading to 0 where H and/or H_ig are zero
   ! TL: needed because e.g. Tp is set to Tpini initially, so shows values even if cell remains dry with H=0
   do k = 1, no_nodes
       if (snapwave_H(k) <= 0.0) then
           snapwave_Tp(k) = 0.0
           snapwave_mean_direction(k) = 0.0
           snapwave_directional_spreading(k) = 0.0
           snapwave_cg(k) = 0.0
       endif
       !
       if (snapwave_H_ig(k) <= 0.0) then
           snapwave_Tp_ig(k) = 0.0
       endif
   enddo
   !
   ! Wave periods from SnapWave, used in e.g. wavemakers - TL: moved behind call update_boundary_conditions & compute_wave_field so values at first timestep are not 0
   !
   snapwave_hsmean = hsmean_bwv
   snapwave_tpmean = tpmean_bwv
   !
   ! Do quick check whether incoming Tpig value seems realistic, before using it:
   if (igwaves) then
       !
       snapwave_tpigmean = tpmean_bwv_ig
       !
       if (snapwave_tpigmean < 10.0) then
           ! These warnings should not occur here
	       write(logstr,*)'DEBUG SFINCS_SnapWave - incoming tp for IG wave at wavemaker might be unrealistically small! value: ',snapwave_tpigmean
           call write_log(logstr, 0)
       elseif (snapwave_tpigmean > 250.0) then
	       write(logstr,*)'DEBUG SFINCS_SnapWave - incoming tp for IG wave at wavemaker might be unrealistically large! value: ',snapwave_tpigmean
           call write_log(logstr, 0)
       endif
   endif
   ! TL: NOTE - in first timestep run of SnapWave tp = 0, therefore excluded that case from the check
   !
   end subroutine

end module
