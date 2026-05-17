module sfincs_diag_dump
   !
   ! SOR-73 env-gated host-side state-divergence dump for the SFINCS CPU
   ! build. Companion to the SOR-51 GPU-side `dump_partition_diff` in
   ! `sfincs_partition.cuf`; this module emits the same CSV schema from a
   ! non-CUDA build so the existing `tests/scripts/diff_partition_dump.py`
   ! can compare a CPU run against a `gpu_n1` run (a CPU↔GPU localizer,
   ! the symmetric peer of SOR-51's `gpu_n1`↔`gpu_n2` localizer).
   !
   ! The dump is a no-op when `SFINCS_DUMP_PARTITION_DIFF` is unset
   ! (single `get_environment_variable` + integer parse + early return).
   ! When set to a positive integer N, every Nth call writes per-step
   ! rows for `zs`, `z_volume`, `zsderv` at cells and `q`, `uv` at edges,
   ! sampled at every cell/edge whose global cell index falls inside one
   ! of two configurable windows (defaults match the GPU dump). Because
   ! the CPU build has no partition, every cell is owned by rank 0 and
   ! the local index IS the global index; `kind` is always `owned` and
   ! `rank` is always 0. Arrays that are not allocated in the current
   ! build configuration (`z_volume` / `zsderv` are subgrid-only) are
   ! skipped.
   !
   use sfincs_data, only: zs, z_volume, zsderv, q, uv, &
                          uv_index_z_nm, uv_index_z_nmu, np, npuv
   implicit none
   private
   public :: dump_state_diff
contains
   !
   subroutine dump_state_diff(step, t)
      !
      integer, intent(in) :: step
      real*8,  intent(in) :: t
      !
      character(len=64)  :: env_period
      character(len=64)  :: env_cmin, env_cmax, env_cmin2, env_cmax2
      character(len=256) :: filename
      integer :: period, ios, nm, ip, g, g_nm, g_nmu
      integer :: unit
      integer :: cmin, cmax, cmin2, cmax2
      logical :: opened, in_win
      logical, save :: header_written = .false.
      !
      call get_environment_variable('SFINCS_DUMP_PARTITION_DIFF', env_period)
      if (len_trim(env_period) == 0) return
      read(env_period, *, iostat=ios) period
      if (ios /= 0 .or. period <= 0) return
      if (mod(step, period) /= 0) return
      !
      cmin  = 3520
      cmax  = 3590
      cmin2 = 23900
      cmax2 = 24160
      call get_environment_variable('SFINCS_DUMP_PARTITION_DIFF_CMIN', env_cmin)
      if (len_trim(env_cmin) > 0) read(env_cmin, *, iostat=ios) cmin
      call get_environment_variable('SFINCS_DUMP_PARTITION_DIFF_CMAX', env_cmax)
      if (len_trim(env_cmax) > 0) read(env_cmax, *, iostat=ios) cmax
      call get_environment_variable('SFINCS_DUMP_PARTITION_DIFF_CMIN2', env_cmin2)
      if (len_trim(env_cmin2) > 0) read(env_cmin2, *, iostat=ios) cmin2
      call get_environment_variable('SFINCS_DUMP_PARTITION_DIFF_CMAX2', env_cmax2)
      if (len_trim(env_cmax2) > 0) read(env_cmax2, *, iostat=ios) cmax2
      !
      filename = 'sfincs_partition_diff_rank0.csv'
      unit = 70
      inquire(unit=unit, opened=opened)
      if (.not. opened) then
         if (header_written) then
            open(unit=unit, file=trim(filename), status='old', position='append', action='write')
         else
            open(unit=unit, file=trim(filename), status='replace', action='write')
            write(unit, '(a)') 'step,t,rank,space,kind,gidx,inc_nm,inc_nmu,array,value'
            header_written = .true.
         end if
      end if
      !
      ! Cell-indexed arrays. CPU has no partition; nm IS the global cell id.
      !
      if (allocated(zs)) then
         do nm = 1, np
            if (.not. ( (nm >= cmin  .and. nm <= cmax ) .or. &
                        (nm >= cmin2 .and. nm <= cmax2) )) cycle
            call write_pdiff_row(unit, step, t, 0, 'cell', 'owned', nm, -1, -1, 'zs', real(zs(nm), kind=8))
         end do
      end if
      if (allocated(z_volume)) then
         do nm = 1, np
            if (.not. ( (nm >= cmin  .and. nm <= cmax ) .or. &
                        (nm >= cmin2 .and. nm <= cmax2) )) cycle
            call write_pdiff_row(unit, step, t, 0, 'cell', 'owned', nm, -1, -1, 'z_volume', real(z_volume(nm), kind=8))
         end do
      end if
      if (allocated(zsderv)) then
         do nm = 1, np
            if (.not. ( (nm >= cmin  .and. nm <= cmax ) .or. &
                        (nm >= cmin2 .and. nm <= cmax2) )) cycle
            call write_pdiff_row(unit, step, t, 0, 'cell', 'owned', nm, -1, -1, 'zsderv', real(zsderv(nm), kind=8))
         end do
      end if
      !
      ! Edge-indexed arrays. Include an edge if either incident z-cell is in-window.
      !
      if (allocated(uv_index_z_nm) .and. allocated(uv_index_z_nmu)) then
         do ip = 1, npuv
            g_nm  = uv_index_z_nm(ip)
            g_nmu = uv_index_z_nmu(ip)
            in_win = ( (g_nm  >= cmin  .and. g_nm  <= cmax ) .or. &
                       (g_nm  >= cmin2 .and. g_nm  <= cmax2) ) .or. &
                     ( (g_nmu >= cmin  .and. g_nmu <= cmax ) .or. &
                       (g_nmu >= cmin2 .and. g_nmu <= cmax2) )
            if (.not. in_win) cycle
            g = ip
            if (allocated(q)  .and. size(q)  >= ip) &
               call write_pdiff_row(unit, step, t, 0, 'edge', 'owned', g, g_nm, g_nmu, 'q',  real(q(ip),  kind=8))
            if (allocated(uv) .and. size(uv) >= ip) &
               call write_pdiff_row(unit, step, t, 0, 'edge', 'owned', g, g_nm, g_nmu, 'uv', real(uv(ip), kind=8))
         end do
      end if
      !
      flush(unit)
      !
   end subroutine dump_state_diff
   !
   subroutine write_pdiff_row(unit, step, t, rank, space, kind, g, inc_nm, inc_nmu, name, value)
      integer,          intent(in) :: unit
      integer,          intent(in) :: step
      real*8,           intent(in) :: t
      integer,          intent(in) :: rank
      character(len=*), intent(in) :: space
      character(len=*), intent(in) :: kind
      integer,          intent(in) :: g, inc_nm, inc_nmu
      character(len=*), intent(in) :: name
      real*8,           intent(in) :: value
      !
      write(unit, '(i0,",",es24.16,",",i0,",",a,",",a,",",i0,",",i0,",",i0,",",a,",",es24.16)') &
         step, t, rank, space, kind, g, inc_nm, inc_nmu, name, value
   end subroutine write_pdiff_row
   !
end module sfincs_diag_dump
