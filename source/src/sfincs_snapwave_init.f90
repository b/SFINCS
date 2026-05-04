module sfincs_snapwave_init
   !
   use sfincs_log
   use sfincs_error
   use sfincs_snapwave_io
   !
   implicit none
   !
   integer                                   :: snapwave_no_cells
   real*8,    dimension(:),   allocatable    :: snapwave_x
   real*8,    dimension(:),   allocatable    :: snapwave_y
   real*4,    dimension(:),   allocatable    :: snapwave_z
   real*4,    dimension(:),   allocatable    :: snapwave_mask
   real*4,    dimension(:),   allocatable    :: snapwave_depth
   real*4,    dimension(:),   allocatable    :: snapwave_H
   real*4,    dimension(:),   allocatable    :: snapwave_H_ig
   real*4,    dimension(:),   allocatable    :: snapwave_Tp
   real*4,    dimension(:),   allocatable    :: snapwave_Tp_ig
   real*4,    dimension(:),   allocatable    :: snapwave_mean_direction
   real*4,    dimension(:),   allocatable    :: snapwave_directional_spreading
   real*4,    dimension(:),   allocatable    :: snapwave_u10
   real*4,    dimension(:),   allocatable    :: snapwave_u10dir
   real*4,    dimension(:),   allocatable    :: snapwave_Fx
   real*4,    dimension(:),   allocatable    :: snapwave_Fy
   real*4,    dimension(:),   allocatable    :: snapwave_Dw
   real*4,    dimension(:),   allocatable    :: snapwave_Df
   real*4,    dimension(:),   allocatable    :: snapwave_Dwig
   real*4,    dimension(:),   allocatable    :: snapwave_Dfig
   real*4,    dimension(:),   allocatable    :: snapwave_cg
   real*4,    dimension(:),   allocatable    :: snapwave_beta
   real*4,    dimension(:),   allocatable    :: snapwave_srcig
   real*4,    dimension(:),   allocatable    :: snapwave_alphaig
   integer,   dimension(:,:), allocatable    :: snapwave_connected_nodes
   real*4                                    :: snapwave_hsmean
   real*4                                    :: snapwave_tpmean
   real*4                                    :: snapwave_tpigmean
   !
contains
   !
   subroutine couple_snapwave(crsgeo)
   !
   use snapwave_data
   use snapwave_domain
   use snapwave_boundaries
   !
   implicit none
   !
   logical       :: crsgeo
   !
   build_revision = '$Rev: svn 197-branch:SnapWave_IG'
   build_date     = '$Date: 2025-04-14'
   !
   call write_log('', 1)
   call write_log('----------- Welcome to SnapWave ---------', 1)
   call write_log('', 1)
   call write_log('   @@@@@   @@  @@  @@@@@@  @@@@@@   @@@  ', 1)
   call write_log('  @@@ @@@  @@@ @@  @@@@@@  @@@@@@   @@@  ', 1)
   call write_log('  @@@      @@@ @@  @@  @@  @@  @@   @@@  ', 1)
   call write_log('   @@@@@   @@@@@@  @@@@@@  @@@@@@   @@@  ', 1)
   call write_log('      @@@  @@ @@@  @@  @@  @@            ', 1)
   call write_log('  @@@ @@@  @@  @@  @@  @@  @@       @@@  ', 1)
   call write_log('   @@@@@   @@   @  @@  @@  @@       @@@  ', 1)
   call write_log('', 1)
   call write_log('             .......:.......             ', 1)
   call write_log('         ...:::::::::::::::::...         ', 1)
   call write_log('      ..:::::::............::::::..      ', 1)
   call write_log('    ..::::::.....:@@@@@@@@....:::::..    ', 1)
   call write_log('   .::::::...~@@@@@@@@@@@@@@~..::::::.   ', 1)
   call write_log('  .::::::..:@@@@@@@@@@@@@@@@@@:.::::::.  ', 1)
   call write_log(' .:::::..:@@@@@@@@@@@@@@@@@@@@@:.::::::. ', 1)
   call write_log('.::::..:@@@@@@@@@@@@@@^......:@@.:::::::.', 1)
   call write_log('.::...:@@@@@@@@@@@@@@@.:::::..^^.:::::::.', 1)
   call write_log('::.:@@@@@@@@@@@@@@@@@@..::::::..:::::::::', 1)
   call write_log('..:@@@@@@@@@@@@@@@@@@@@^..............::.', 1)
   call write_log('..:@@@@@@@@@@@@@@@@@@@@@@@^:..:~^~^~:..:.', 1)
   call write_log(' .:@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@:. ', 1)
   call write_log('  .@@~^~@@@@~^~@@@@~^~@@@@~^~@@@@~^~@@.  ', 1)
   call write_log('   ...................................   ', 1)
   call write_log('    ..:::::::::::::::::::::::::::::..    ', 1)
   call write_log('      ..:::::::::::::::::::::::::..      ', 1)
   call write_log('         ...:::::::::::::::::...         ', 1)
   call write_log('             .......:.......             ', 1)
   call write_log('', 1)
   call write_log('-----------------------------------------', 1)
   call write_log('', 1)
   call write_log('Build-Revision: '//trim(build_revision), 1)
   call write_log('Build-Date: '//trim(build_date), 1)
   call write_log('', 1)
   call write_log('------ Preparing model simulation --------', 1)
   call write_log('', 1)
   !
   ! Check whether SFINCS grid is spherical (T) or cartesian (F), and prescribe to SnapWave as variable 'sferic' -  spherical (1) or cartesian (0) grid
   if (crsgeo) then
      sferic  = 1
      write(logstr,*)'SnapWave: Input grid interpreted as spherical coordinates, sferic= ',sferic
      call write_log(logstr, 0)
   endif
   !
   call read_snapwave_input()            ! Reads snapwave.inp
   !
   call initialize_snapwave_domain()     ! Read mesh, finds upwind neighbors, etc.
   !
   call read_boundary_data()
   !
   !call find_boundary_indices() ! > is already called in read_boundary_data()
   !
   call write_log('', 1)
   !
   snapwave_no_nodes = no_nodes
   !
   allocate(snapwave_z(no_nodes))
   allocate(snapwave_depth(no_nodes))
   allocate(snapwave_mask(no_nodes))
   allocate(snapwave_u10(no_nodes))
   allocate(snapwave_u10dir(no_nodes))
   !
   snapwave_z     = zb
   snapwave_depth = 0.0
   !
   if (wind) then
      snapwave_u10 = 0.0
      snapwave_u10dir = 0.0
   endif
   !
   snapwave_hsmean = 0.0
   snapwave_tpmean = 0.0
   snapwave_tpigmean = 0.0
   !
   call find_matching_cells(index_quadtree_in_snapwave, index_snapwave_in_quadtree)
   !
   ! Copy final snapwave mask from snapwave_domain for output in sfincs_ncoutput
   !
   snapwave_mask = msk
   !
   call write_log('------------------------------------------', 1)
   call write_log('SnapWave Processes', 1)
   call write_log('------------------------------------------', 1)
   if (igwaves) then
      call write_log('SnapWave IG waves                  : yes', 1)
   else
      call write_log('SnapWave IG waves                  : no', 1)
   endif
   if (iterative_srcig) then
      call write_log('SnapWave implicit IG source term   : yes', 1)
   else
      call write_log('SnapWave implicit IG source term   : no', 1)
   endif
   if (igherbers) then
      call write_log('SnapWave IG bc using Herbers       : yes', 1)
   else
      call write_log('SnapWave IG bc using Herbers       : no', 1)
   endif
   if (wind) then
      call write_log('SnapWave wind growth               : yes', 1)
   else
      call write_log('SnapWave wind growth               : no', 1)
   endif
   if (vegetation) then
      call write_log('SnapWave vegetation                : yes', 1)
   else
      call write_log('SnapWave vegetation                : no', 1)
   endif
   !
   call write_log('------------------------------------------', 1)
   !
   end subroutine

end module
