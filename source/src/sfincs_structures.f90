   module sfincs_structures

   use sfincs_error
   use sfincs_log
   use sfincs_structures_io, only: io_read_structures           => read_structures, &
                                   io_read_structure_file       => read_structure_file, &
                                   io_read_thin_dams            => read_thin_dams, &
                                   io_give_structure_information => give_structure_information, &
                                   io_give_thindam_information  => give_thindam_information

   contains

   subroutine read_structures()
   !
   ! Trampoline to sfincs_structures_io::read_structures
   !
   implicit none
   !
   call io_read_structures()
   !
   end subroutine


   subroutine read_structure_file(filename, itype, npars)
   !
   ! Trampoline to sfincs_structures_io::read_structure_file
   !
   implicit none
   !
   integer       :: itype, npars
   character*256 :: filename
   !
   call io_read_structure_file(filename, itype, npars)
   !
   end subroutine


   subroutine read_thin_dams()
   !
   ! Trampoline to sfincs_structures_io::read_thin_dams
   !
   implicit none
   !
   call io_read_thin_dams()
   !
   end subroutine


   subroutine give_structure_information(struc_info)
   !
   ! Trampoline to sfincs_structures_io::give_structure_information
   !
   implicit none
   !
   real*4, dimension(:,:), allocatable :: struc_info
   !
   call io_give_structure_information(struc_info)
   !
   end subroutine


   subroutine give_thindam_information(struc_info)
   !
   ! Trampoline to sfincs_structures_io::give_thindam_information
   !
   implicit none
   !
   real*4, dimension(:,:), allocatable :: struc_info
   !
   call io_give_thindam_information(struc_info)
   !
   end subroutine


   subroutine compute_fluxes_over_structures(tloop)
   !
   ! Computes fluxes over structures (THIS HAS TO BE SERIOUSLY IMPROVED!!!)
   !
   use sfincs_data
!   use quadtree
   !
   implicit none
   !
   integer                       :: ip
   integer*4                     :: nm
   integer*4                     :: nmu
   integer                       :: istruc
   integer                       :: ikf
   integer                       :: idir
   !
   real*4                       :: zsnm
   real*4                       :: zsnmu
   real*4                       :: cweir
   real*4                       :: Cd
   real*4                       :: m
   real*4                       :: h1
   real*4                       :: h2
   real*4                       :: qstruc
   !
   integer  :: count0
   integer  :: count1
   integer  :: count_rate
   integer  :: count_max
   real     :: tloop
   !
   call system_clock(count0, count_rate, count_max)
   !
   do istruc = 1, nrstructures
      !
      ip     = structure_uv_index(istruc)
      !
      q(ip)  = 0.0
      uv(ip) = 0.0
      !
      nm  = uv_index_z_nm(ip)
      nmu = uv_index_z_nmu(ip)
      !
      zsnm  = zs(nm)
      zsnmu = zs(nmu)
      !
      if (zsnm<structure_parameters(1, istruc) .and. zsnmu<structure_parameters(1, istruc)) then
         !
         cycle ! No flow over structure
         !
      endif
      !
      select case(structure_type(istruc))
         case(1)
            !
            ! Broad-crested weir
            !
            cweir = 1.7049
            m = 0.0 ! Modular limit ...
            Cd = structure_parameters(2, istruc)
            !
            ikf   = 0
            !
            ikf   = 1  ! use flux now
            !
            if  (zsnm>zsnmu) then
               idir = 1
               h1 = zsnm  - structure_parameters(1, istruc)
               h2 = zsnmu - structure_parameters(1, istruc)
            else
               idir = -1
               h1 = zsnmu - structure_parameters(1, istruc)
               h2 = zsnm  - structure_parameters(1, istruc)
            endif
            !
            if (h2 > 2.0 / 3.0 * h1) then
               !
               ! fully submerged
               !
               qstruc = Cd*h2*sqrt(2.0 * 9.81 * (h1 - h2)/(1.0 - m))
               !
            else
               !
               ! free flow
               !
               qstruc = Cd*cweir*h1**1.5
               !
            endif
            !
         case(2)
         case(3)
      end select
      !
      qstruc = qstruc * structure_length(istruc)
      !
      q(ip)  = qstruc*idir ! Add relaxation here !!!
      !
   enddo
   !
   call system_clock(count1, count_rate, count_max)
   tloop = tloop + 1.0*(count1 - count0)/count_rate
   !
   end subroutine



end module
