   module sfincs_wavemaker

   use sfincs_log
   use sfincs_error
   use sfincs_wavemaker_io

   contains



   subroutine update_wavemaker_fluxes(t, dt, tloop)
   !
   ! Update fluxes qx and qy at wave maker points
   !
   use sfincs_data
   use sfincs_snapwave
   !
   implicit none
   !
   integer :: ib, nmi, nmb, iuv, ip, ifreq, itb, itb0, itb1, kst
   real*4  :: hnmb, dt, zsnmi, zsnmb, zs0nmb, zwav_ig, zwav_inc
   real*4  :: alpha, beta
   real*8  :: t, tb
   real*4  :: tbfac, hs, tp_ig, tp_inc, tpsum, setup, fm_ig, a, fm_inc
   real*4  :: wave_steepness, betas, zinc, zig, dwvm, ztot, hm0_inc
   real*4  :: ui, ub, dzuv, facint, zsuv, depthuv, uvm0
   !
   integer  :: count0
   integer  :: count1
   integer  :: count_rate
   integer  :: count_max
   real     :: tloop
   !
   real*4, dimension(:),     allocatable :: wavemaker_forcing_hm0_ig_t
   real*4, dimension(:),     allocatable :: wavemaker_forcing_tp_ig_t
   real*4, dimension(:),     allocatable :: wavemaker_forcing_setup_t   
   !
   call system_clock(count0, count_rate, count_max)
   !
   ! Factors for double-exponential filtering
   !
   alpha = min(dt / wavemaker_filter_time, 1.0)
   beta  = min(dt / (0.2 * wavemaker_filter_time), 1.0)
   !
   ! For time series forcing, we now update values at the forcing points and determine Tp_ig
   ! For forcing with SnapWave, we only need to determine Tp_ig
   !
   if (wavemaker_timeseries) then
      !
      ! Only IG wave forcing supported at the moment !
      !
      allocate(wavemaker_forcing_hm0_ig_t(wavemaker_nr_forcing_points))
      allocate(wavemaker_forcing_tp_ig_t(wavemaker_nr_forcing_points))
      allocate(wavemaker_forcing_setup_t(wavemaker_nr_forcing_points))
      !
      ! Interpolate boundary conditions in time
      !
      if (wavemaker_forcing_time(1) > t - 1.0e-3) then ! use first time in boundary conditions
         !
         itb0 = 1
         itb1 = 1
         tb   = wavemaker_forcing_time(itb0)
         !
      elseif (wavemaker_forcing_time(wavemaker_nr_forcing_timesteps) < t + 1.0e-3) then  ! use last time in boundary conditions       
         !
         itb0 = wavemaker_nr_forcing_timesteps
         itb1 = wavemaker_nr_forcing_timesteps
         tb   = wavemaker_forcing_time(itb0)
         !
      else
         !
         do itb = wavemaker_itlast, wavemaker_nr_forcing_timesteps ! Loop in time
            if (wavemaker_forcing_time(itb) > t + 1.0e-6) then
               itb0 = itb - 1
               itb1 = itb
               tb   = t
               wavemaker_itlast = itb - 1
               exit
            endif
         enddo 
         !
      endif            
      !
      tbfac  = (tb - wavemaker_forcing_time(itb0)) / max(wavemaker_forcing_time(itb1) - wavemaker_forcing_time(itb0), 1.0e-6)
      !
      tpsum = 0.0
      !
      do ib = 1, wavemaker_nr_forcing_points ! Loop along forcing points
         !
         hs    = wavemaker_forcing_hm0_ig(ib, itb0) + (wavemaker_forcing_hm0_ig(ib, itb1) - wavemaker_forcing_hm0_ig(ib, itb0)) * tbfac
         tp_ig = wavemaker_forcing_tp_ig(ib, itb0)  + (wavemaker_forcing_tp_ig(ib, itb1)  - wavemaker_forcing_tp_ig(ib, itb0)) * tbfac
         setup = wavemaker_forcing_setup(ib, itb0)  + (wavemaker_forcing_setup(ib, itb1)  - wavemaker_forcing_setup(ib, itb0)) * tbfac
         !
         wavemaker_forcing_hm0_ig_t(ib) = hs
         wavemaker_forcing_setup_t(ib)  = setup
         !
         tpsum = tpsum + tp_ig
         !
      enddo
      !
      tp_ig = tpsum / wavemaker_nr_forcing_points ! Take average Tp from boundary points
      tp_inc = 10.0 ! Later make it possible to also specify Tp_inc in time series forcing, but for now just add a fixed value (that is not used)
      !
   else
      !
      ! Use mean peak period from SnapWave boundary conditions
      !
      tp_ig = snapwave_tpigmean ! TL: Now calculated in SnapWave, different options for using a period based on Herbers spectrum (snapwave_tpig_opt, if snapwave_use_herbers=1, or user defined snapwave_Tinc2ig ratio (if snapwave_use_herbers = 0)
      !
      ! We may want to use Herbers for computation of IG waves in SnapWave, but we want to have control over peak IG period at wave makers.
      !
      if (wavemaker_Tinc2ig > 0.0) then
         !
         ! Use factor on mean Tp_inc at boundaries
         !
         tp_ig = snapwave_tpmean * wavemaker_Tinc2ig
         !
!      elseif (wavemaker_surfslope > 0.0) then ! Dean a
!         !
!         ! Turn this option off now, because snapwave_hsmean is not available in current branch
!         ! Will need to be updated if we want to use this option, but it is not a priority at the moment
!         !
!         ! Estimate surfzone slope from Dean's a, using gambr = 1.0
!         !
!         betas = snapwave_hsmean / (snapwave_hsmean / (1.0 * wavemaker_surfslope))**(3.0 / 2.0)
!         !
!         wave_steepness = snapwave_hsmean / (1.56 * snapwave_tpmean**2)
!         !
!         ! From empirical run-up equation (van Ormondt et al., 2021), but slightly adjusted
!         !
!         tp_ig = snapwave_tpmean * max(1.86 * betas**-0.43 * wave_steepness**0.07, 5.0)
!         !
      endif
      !
      tp_inc = max(snapwave_tpmean, wavemaker_tpmin)
      !
      tp_ig = max(tp_ig, wavemaker_tpmin)      
      ! 
   endif      
   !
   ! Now determine zwav_ig and zwav_inc based on spectrum or monochromatic signal.
   ! Time series of zwav_ig and zwav_inc will be used to modulate water level at wave maker points.
   ! They both give at Hm0 of 1.0 m, and therefore need to be scaled with the data at the wave maker points (either from time series or SnapWave boundary conditions)
   !
   zwav_ig = 0.0
   zwav_inc = 0.0
   !
   if (wavemaker_spectrum) then
      !
      ! Infragravity waves
      !
      if (wavemaker_hig) then
         !
         fm_ig = 1.0 / tp_ig ! Wave period
         !
         ! Now spectrum and wave excitation
         !
         do ifreq = 1, wavemaker_nfreqs_ig
            !
            ! Update phase
            !
            wavemaker_phi_ig(ifreq) = modulo(wavemaker_phi_ig(ifreq) + wavemaker_dphi_ig(ifreq) * dt, 2 * pi)
            wavemaker_cost_ig(ifreq) = cos(2 * pi * t * wavemaker_freq_ig(ifreq) + wavemaker_phi_ig(ifreq))         
            !
            ! Use this spectral shape instead
            !
            a = 0.125 * (fm_ig**-2) * wavemaker_freq_ig(ifreq) * (exp(-wavemaker_freq_ig(ifreq) / fm_ig))
            !
            zwav_ig = zwav_ig + wavemaker_cost_ig(ifreq) * sqrt(a * wavemaker_dfreq_ig)
            !
         enddo
         !
      endif
      !
      if (wavemaker_hinc) then
         !
         fm_inc = 1.0 / tp_inc ! Wave period
         !
         do ifreq = 1, wavemaker_nfreqs_inc
            !
            wavemaker_phi_inc(ifreq) = modulo(wavemaker_phi_inc(ifreq) + wavemaker_dphi_inc(ifreq) * dt, 2 * pi)
            wavemaker_cost_inc(ifreq) = cos(2 * pi * t * wavemaker_freq_inc(ifreq) + wavemaker_phi_inc(ifreq))
            !
            ! The ISSC spectrum (also known as Bretschneider or modified Pierson-Moskowitz)
            !
            a = 0.625 * (fm_inc**4) * (wavemaker_freq_inc(ifreq)**-5) * (exp(-1.25 * (wavemaker_freq_inc(ifreq) / fm_inc)**-4))
            !
            zwav_inc = zwav_inc + wavemaker_cost_inc(ifreq) * sqrt(a * wavemaker_dfreq_inc)  
            !
         enddo
         !
         !zwav_inc = 0.5 * sin(2 * pi * t / tp_inc)
         !
         ! Saw tooth
         !
         !zwav_inc = - mod(t, tp_inc) / tp_inc + 0.5
         !
         ! Let zwav_inc be modulated by zwav_ig (i.e. higher incident waves at the peaks of the IG wave)
         !
         !zwav_inc = zwav_inc * sqrt(max(zwav + 1.0, 0.0)) ! this assumes zwav is somewhere between -0.5 and +0.5
         !
      endif   
      !
   else
      !
      ! Monochromatic signal
      !
      if (wavemaker_hig) then
         !
         zwav_ig = 0.5 * sin(2 * pi * t / tp_ig)
         !
      endif
      !
      if (wavemaker_hinc) then
         !
         zwav_inc = 0.5 * sin(2 * pi * t / tp_inc)
         !
      endif   
      !
   endif   
   !
   if (t < tspinup) then
      !
      zwav_ig = zwav_ig * (t - t0) / (tspinup - t0)
      zwav_inc = zwav_inc * (t - t0) / (tspinup - t0)
      !
   endif
   !
   ! UV fluxes at wave makers
   !
   ! No OMP acceleration here?
   !
   do ib = 1, wavemaker_nr_uv_points
      !
      ip     = wavemaker_index_uv(ib)
      nmi    = wavemaker_index_nmi(ib)
      nmb    = wavemaker_index_nmb(ib)
      !
      zsnmi  = zs(nmi)                    ! total water level on wave side inside model
      !
      ! Now determine total water levels (zs0nmb and zsnmb) on boundary (i.e. wave maker) side,
      ! which is based on mean water level plus wave height
      !
      if (wavemaker_timeseries) then
         !
         ! Take wave height from boundary conditions file (weighted average of two nearby forcing points)
         !
         hs    = wavemaker_forcing_hm0_ig_t(wavemaker_index_wmfp1(ib)) * wavemaker_fac_wmfp(ib) + wavemaker_forcing_hm0_ig_t(wavemaker_index_wmfp2(ib)) * (1.0 - wavemaker_fac_wmfp(ib))
         setup = wavemaker_forcing_setup_t(wavemaker_index_wmfp1(ib)) * wavemaker_fac_wmfp(ib)  + wavemaker_forcing_setup_t(wavemaker_index_wmfp2(ib)) * (1.0 - wavemaker_fac_wmfp(ib))
         !
         zs0nmb = zs(nmb) + setup            ! average water level inside model without waves (this should be zs)
         zsnmb  = zs0nmb + zwav_ig * hs      ! total water level in wave maker (i.e. mean water level plus wave)         
         !
      else
         !
         ! Take wave height from SnapWave
         !
         zs0nmb = zs(nmb) ! average water level inside model without waves
         !
         zig    = wavemaker_hm0_ig_factor * zwav_ig * hm0_ig(nmb)
         zinc   = wavemaker_hm0_inc_factor * zwav_inc * hm0(nmb)
         !
         ! Compute water depth including IG wave
         !
         if (subgrid) then
            dwvm   = max(zs0nmb + zig - subgrid_z_zmax(nmb), 0.0) ! depth at wave maker
         else
            dwvm   = max(zs0nmb + zig - zb(nmb), 0.0) ! depth at wave maker
         endif
         !
         ! Limit incident wave height
         !
         zsnmb  = zs0nmb + min(zinc + zig,  wavemaker_gammax * dwvm) ! total water level in wave maker (i.e. mean water level plus wave)
         !
      endif   
      !
      if (subgrid) then
         !
         zsuv = max(zsnmb, zsnmi)
         !
         if (zsuv >= subgrid_uv_zmax(ip) - 1.0e-3) then
            !
            ! Entire cell is wet, no interpolation from table needed
            !
            depthuv  = subgrid_uv_havg_zmax(ip) + zsuv
            !
         elseif (zsuv > subgrid_uv_zmin(ip)) then
            !
            ! Interpolation required
            !            
            dzuv    = (subgrid_uv_zmax(ip) - subgrid_uv_zmin(ip)) / (subgrid_nlevels - 1)
            iuv     = int((zsuv - subgrid_uv_zmin(ip)) / dzuv) + 1
            facint  = (zsuv - (subgrid_uv_zmin(ip) + (iuv - 1) * dzuv) ) / dzuv
            depthuv = subgrid_uv_havg(iuv, ip) + (subgrid_uv_havg(iuv + 1, ip) - subgrid_uv_havg(iuv, ip)) * facint
            !
         else
            !
            depthuv = 0.0
            !
         endif
         !
         hnmb   = depthuv
         zsnmb  = max(zsnmb,  subgrid_z_zmin(nmb))
         zs0nmb = max(zs0nmb, subgrid_z_zmin(nmb))
         !
      else
         !
         hnmb   = 0.5 * (zsnmb + zsnmi) - zbuv(ip)
         zsnmb  = max(zsnmb, zb(nmb))
         zs0nmb = max(zs0nmb, zb(nmb))
         !
      endif
      !
      ! Use weakly reflective boundary condition 
      !
      if (hnmb < wavemaker_hmin) then
         !
         ! Very shallow
         !
         q(ip) = 0.0
         wavemaker_uvmean(ib) = 0.0
         !
      else
         !
         ui = sqrt(g / hnmb) * (zsnmb - zs0nmb)
         ub = wavemaker_idir(ib) * (2 * ui - sqrt(g / hnmb) * (zsnmi - zs0nmb)) * wavemaker_angfac(ib)
         !
         q(ip) = ub * hnmb + wavemaker_uvmean(ib)
         !
      endif
      !
      if (wavemaker_filter_time >= 0.0) then
         !
         ! Use double exponential time filter
         !
         uvm0 = wavemaker_uvmean(ib) ! Previous time step
         wavemaker_uvmean(ib)  = alpha * q(ip) + wavemaker_filter_fred * (1.0 - alpha) * (wavemaker_uvmean(ib) + wavemaker_uvtrend(ib))
         wavemaker_uvtrend(ib) = beta * (wavemaker_uvmean(ib) - uvm0) + (1.0 - beta) * wavemaker_uvtrend(ib)
         !
      else
         !
         wavemaker_uvmean(ib) = 0.0
         !
      endif
      !
   enddo
   !
   call system_clock(count1, count_rate, count_max)
   tloop = tloop + 1.0*(count1 - count0)/count_rate
   !
   end subroutine
      
   end module
