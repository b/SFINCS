module sfincs_snapwave_io
   !
   use sfincs_log
   use sfincs_error
   !
   implicit none
   !
contains
   !
   subroutine read_snapwave_input()
   !
   ! Reads snapwave data from sfincs.inp
   !
   use snapwave_data
   !
   implicit none
   !
   open(500, file='sfincs.inp')
   !
   ! Input section
   !
   call read_real_input(500, 'snapwave_gamma', gamma, 0.7)
   call read_real_input(500, 'snapwave_gammax', gammax, 2.0) ! MvO - Changed default gammax from 0.6 to 2.0
   call read_real_input(500, 'snapwave_alpha', alpha, 1.0)
   call read_real_input(500, 'snapwave_hmin', hmin, 0.1)
   call read_real_input(500, 'snapwave_fw', fw0, 0.01)
   call read_real_input(500, 'snapwave_fwig', fw0_ig, 0.015)
   call read_real_input(500, 'snapwave_dt', dt, 36000.0)
   call read_real_input(500, 'snapwave_tol', tol, 1000.0)
   call read_real_input(500, 'snapwave_dtheta', dtheta, 10.0)
   call read_real_input(500, 'snapwave_crit', crit, 0.001) !TL: Old default was 0.01
   call read_int_input(500,  'snapwave_nrsweeps', nr_sweeps, 4)
   call read_int_input(500,  'snapwave_niter', niter, 10)
   call read_int_input(500,  'snapwave_baldock_opt', baldock_opt, 1)
   call read_real_input(500, 'snapwave_baldock_ratio', baldock_ratio, 0.2)
   call read_real_input(500, 'rgh_lev_land', rghlevland, 0.0)
   call read_real_input(500, 'snapwave_fw_ratio', fwratio, 1.0)
   call read_real_input(500, 'snapwave_fwig_ratio', fwigratio, 1.0)
   call read_real_input(500, 'snapwave_Tpini', Tpini, 1.0)
   call read_int_input (500, 'snapwave_mwind', mwind, 2)
   call read_real_input(500, 'snapwave_sigmin', sigmin, 8.0 * atan(1.0) / 25.0)
   call read_real_input(500, 'snapwave_sigmax', sigmax, 8.0 * atan(1.0) / 1.0)
   call read_int_input (500, 'snapwave_jadcgdx', jadcgdx, 1)
   call read_real_input(500, 'snapwave_c_dispT', c_dispT, 1.0)
   call read_real_input(500, 'snapwave_sector', sector, 180.0)
   !
   ! Settings related to IG waves
   !
   call read_int_input(500, 'snapwave_igwaves', igwaves_opt, 1)                  ! Compute IG waves (1=default), or not (0)
   call read_real_input(500, 'snapwave_alpha_ig', alpha_ig, 1.0)                 ! TODO choose whether snapwave_alphaig or snapwave_gamma_ig
   call read_real_input(500, 'snapwave_gammaig', gamma_ig, 0.2)                  ! Wave breaking parameter for IG waves, default=0.2
   call read_real_input(500, 'snapwave_shinc2ig', shinc2ig, 1.0)                 ! Ratio of how much of the calculated IG wave source term, is subtracted from the incident wave energy (0-1, 1=default=all energy as sink)
   call read_real_input(500, 'snapwave_alphaigfac', alphaigfac, 1.0)             ! Multiplication factor for IG shoaling source/sink term
   call read_real_input(500, 'snapwave_baldock_ratio_ig', baldock_ratio_ig, 0.2) ! ! option controlling from what depth wave breaking should take place for IG waves, default baldock_ratio_ig=0.2
   call read_int_input(500, 'snapwave_ig_opt', ig_opt, 1)                        ! option of IG wave settings (1 = default = conservative shoaling based dSxx as in Leijnse et al. 2024)
   call read_int_input(500, 'snapwave_iterative_srcig', iterative_srcig_opt, 0)  ! Option whether to calculate IG source/sink term in iterative lower (better, but potentially slower, 1), or effectively based on previous timestep (faster, potential mismatch, =0=default)
   !
   ! IG boundary conditions options
   !
   call read_int_input(500, 'snapwave_use_herbers', herbers_opt, 1)   ! Choice whether you want IG Hm0&Tp be calculated by herbers (=1, default), or want to specify user defined values (0> then snapwave_eeinc2ig & snapwave_Tinc2ig are used)
   call read_int_input(500, 'snapwave_tpig_opt', tpig_opt, 1)         ! IG wave period option based on Herbers calculated spectrum, only used if snapwave_use_herbers = 1. Options are: 1=Tm01 (default), 2=Tpsmooth, 3=Tp, 4=Tm-1,0
   call read_real_input(500, 'snapwave_jonswapgamma',jonswapgam, 3.3) ! JONSWAP gamma value for determination offshore spectrum and IG wave conditions using Herbers, default=3.3, only used if snapwave_use_herbers = 1
   call read_real_input(500, 'snapwave_eeinc2ig', eeinc2ig, 0.01)    ! Only used if snapwave_use_herbers = 0
   call read_real_input(500, 'snapwave_Tinc2ig', Tinc2ig, 7.0)        ! Only used if snapwave_use_herbers = 0
   !
   ! Wind
   !
   call read_int_input(500,'snapwave_wind',wind_opt,0)   ! Flag whether to include windgrowth in SnapWave (1) or not (0, default)
   !
   ! Vegetation input
   !
   call read_int_input(500, 'vegetation', vegetation_opt, 0)
   !
   ! Input files
   !
   call read_char_input(500, 'snapwave_jonswapfile', snapwave_jonswapfile, 'none')
   call read_char_input(500, 'snapwave_bndfile', snapwave_bndfile, 'none')
   call read_char_input(500, 'snapwave_encfile', snapwave_encfile, 'none')
   call read_char_input(500, 'snapwave_bhsfile', snapwave_bhsfile, 'none')
   call read_char_input(500, 'snapwave_btpfile', snapwave_btpfile, 'none')
   call read_char_input(500, 'snapwave_bwdfile', snapwave_bwdfile, 'none')
   call read_char_input(500, 'snapwave_bdsfile', snapwave_bdsfile,'none')
   call read_char_input(500, 'snapwave_upwfile', upwfile, 'snapwave.upw')
   call read_char_input(500, 'snapwave_mskfile', mskfile, 'none')
   call read_char_input(500, 'snapwave_depfile', depfile, 'none')
   call read_char_input(500, 'snapwave_ncfile',  gridfile, 'snapwave_net.nc')
   call read_char_input(500, 'netsnapwavefile', netsnapwavefile, 'none')
   call read_char_input(500, 'tref', trefstr, '20000101 000000')   ! Read again > needed in sfincs_ncinput.F90
   !
   close(500)
   !
   igwaves          = .true.
   igherbers        = .false.
   iterative_srcig  = .false.
   !
   if (igwaves_opt==0) then
      !
      igwaves       = .false.
      !
   else
      !
      if (iterative_srcig_opt==1) then
         iterative_srcig = .true.
      endif
      !
      if (herbers_opt==0) then
         !
         write(logstr,*)'SnapWave: IG bc using use eeinc2ig= ',eeinc2ig,' and snapwave_Tinc2ig= ',Tinc2ig
         call write_log(logstr, 0)
         !
      else
         !
         igherbers     = .true.
         !
      endif
      !
   endif
   !
   wind = .true.
   if (wind_opt==0) then
      wind = .false.
   endif
   !
   vegetation = .true.
   !
   if (vegetation_opt == 0) then
      vegetation = .false.
   endif
   !
   if (nr_sweeps /= 1 .and. nr_sweeps /= 4) then
      !
      nr_sweeps = 4
      call write_log('SnapWave: Warning! nr_sweeps must be 1 or 4! Now set to 4.', 1)
      !
   endif
   !
   restart           = .true.
   coupled_to_sfincs = .true.
   !
   end subroutine



   subroutine read_real_input(fileid,keyword,value,default)
   !
   character(*), intent(in) :: keyword
   character(len=256)       :: keystr
   character(len=256)       :: valstr
   character(len=256)       :: line
   integer, intent(in)      :: fileid
   real*4, intent(out)      :: value
   real*4, intent(in)       :: default
   integer j,stat,ilen
   !
   value = default
   !
   rewind(fileid)
   !
   do while(.true.)
      !
      read(fileid,'(a)',iostat = stat)line
      !
      if (stat==-1) exit
      !
      call read_line(line, keystr, valstr)
      !
      if (trim(keystr)==trim(keyword)) then
         !
         read(valstr,*)value
         !
         exit
         !
      endif
      !
   enddo
   !
   end  subroutine

   subroutine read_real_array_input(fileid,keyword,value,default,nr)
   !
   character(*), intent(in) :: keyword
   character(len=256)       :: keystr
   character(len=256)       :: valstr
   character(len=256)       :: line
   integer, intent(in)      :: fileid
   integer, intent(in)      :: nr
   real*4, dimension(:), intent(out), allocatable :: value
   real*4, intent(in)       :: default
   integer j,stat, m,ilen
   !
   allocate(value(nr))
   !
   value = default
   !
   rewind(fileid)
   !
   do while(.true.)
      !
      read(fileid,'(a)',iostat = stat)line
      !
      if (stat==-1) exit
      !
      call read_line(line, keystr, valstr)
      !
      if (trim(keystr)==trim(keyword)) then
         !
         read(valstr,*)(value(m), m = 1, nr)
         !
         exit
         !
      endif
      !
   enddo
   !
   end  subroutine


   subroutine read_int_input(fileid,keyword,value,default)
   !
   character(*), intent(in) :: keyword
   character(len=256)       :: keystr
   character(len=256)       :: valstr
   character(len=256)       :: line
   integer, intent(in)      :: fileid
   integer, intent(out)     :: value
   integer, intent(in)      :: default
   integer j,stat,ilen
   !
   value = default
   !
   rewind(fileid)
   !
   do while(.true.)
      !
      read(fileid,'(a)',iostat = stat)line
      !
      if (stat==-1) exit
      !
      call read_line(line, keystr, valstr)
      !
      if (trim(keystr)==trim(keyword)) then
         !
         read(valstr,*)value
         !
         exit
         !
      endif
      !
   enddo
   !
   end subroutine


   subroutine read_char_input(fileid,keyword,value,default)
   !
   character(*), intent(in)  :: keyword
   character(len=256)        :: keystr0
   character(len=256)        :: keystr
   character(len=256)        :: valstr
   character(len=256)        :: line
   integer, intent(in)       :: fileid
   character(*), intent(in)  :: default
   character(*), intent(out) :: value
   integer j,stat,ilen,jn
   !
   value = default
   !
   rewind(fileid)
   !
   do while(.true.)
      !
      read(fileid,'(a)',iostat = stat)line
      !
      if (stat==-1) exit
      !
      call read_line(line, keystr, valstr)
      !
      if (trim(keystr)==trim(keyword)) then
         !
         value = valstr
         !
         exit
         !
      endif
      !
   enddo
   !
   end subroutine

   subroutine read_logical_input(fileid,keyword,value,default)
   !
   character(*), intent(in)  :: keyword
   character(len=256)        :: keystr0
   character(len=256)        :: keystr
   character(len=256)        :: valstr
   character(len=256)        :: line
   integer, intent(in)       :: fileid
   logical, intent(in)       :: default
   logical, intent(out)      :: value
   integer j,stat,ilen
   !
   value = default
   !
   rewind(fileid)
   !
   do while(.true.)
      !
      read(fileid,'(a)',iostat = stat)line
      !
      if (stat==-1) exit
      !
      call read_line(line, keystr, valstr)
      !
      if (trim(keystr)==trim(keyword)) then
         !
         if (valstr(1:1) == '1' .or. valstr(1:1) == 'y' .or. valstr(1:1) == 'Y' .or. valstr(1:1) == 't' .or. valstr(1:1) == 'T') then
            value = .true.
         else
            value = .false.
         endif
         !
         exit
         !
      endif
      !
   enddo
   !
   end subroutine

   subroutine read_line(line0, keystr, valstr)
   !
   ! Reads line from input file, returns keyword and value strings
   !
   character(*), intent(in)  :: line0
   character(len=256)        :: line
   character(*), intent(out) :: keystr
   character(*), intent(out) :: valstr
   integer j, ilen, jn
   !
   keystr = ''
   valstr = ''
   !
   ! Change tabs into spaces.
   !
   call notabs(line0, line, ilen)
   !
   ! Look for line ending character. Remove it if it exists.
   !
   jn = index(line, '\r')
   !
   if (jn > 0) then
      !
      ! New line character detected (probably sfincs.inp with windows line endings, running in linux)
      !
      line = line(1 : jn - 1)
      !
   endif
   !
   ! Remove leading and trailing spaces.
   !
   line = trim(line)
   !
   if (line(1:1) == '#' .or. line(1:1) == '!' .or. line(1:1) == '@') return
   !
   ! Find "="
   !
   j  = index(line, '=')
   !
   if (j == 0) return
   !
   keystr = trim(line(1:j-1))
   !
   valstr = trim(line(j+1:))
   !
   ! Remove comments
   !
   jn = index(valstr, '#')
   !
   if (jn > 0) then
      !
      valstr = trim(valstr(1 : jn - 1))
      !
   endif
   !
   valstr = adjustl(trim(valstr))
   !
   end subroutine


   subroutine notabs(INSTR,OUTSTR,ILEN)
   ! @(#) convert tabs in input to spaces in output while maintaining columns, assuming a tab is set every 8 characters
   !
   ! USES:
   !       It is often useful to expand tabs in input files to simplify further processing such as tokenizing an input line.
   !       Some FORTRAN compilers hate tabs in input files; some printers; some editors will have problems with tabs
   ! AUTHOR:
   !       John S. Urban
   !
   ! SEE ALSO:
   !       GNU/Unix commands expand(1) and unexpand(1)
   !
   use ISO_FORTRAN_ENV, only : ERROR_UNIT     ! get unit for standard error. if not supported yet,  define ERROR_UNIT for your system (typically 0)
   character(len=*),intent(in)   :: INSTR     ! input line to scan for tab characters
   character(len=*),intent(out)  :: OUTSTR    ! tab-expanded version of INSTR produced
   integer,intent(out)           :: ILEN      ! column position of last character put into output string

   integer,parameter             :: TABSIZE=8 ! assume a tab stop is set every 8th column
   character(len=1)              :: c         ! character read from stdin
   integer                       :: ipos      ! position in OUTSTR to put next character of INSTR
   integer                       :: lenin     ! length of input string trimmed of trailing spaces
   integer                       :: lenout    ! number of characters output string can hold
   integer                       :: i10       ! counter that advances thru input string INSTR one character at a time
   !
   IPOS=1                                  ! where to put next character in output string OUTSTR
   lenin=len(INSTR)                        ! length of character variable INSTR
   lenin=len_trim(INSTR(1:lenin))          ! length of INSTR trimmed of trailing spaces
   lenout=len(OUTSTR)                      ! number of characters output string OUTSTR can hold
   OUTSTR=" "                              ! this SHOULD blank-fill string, a buggy machine required a loop to set all characters
   !
   do i10=1,lenin                          ! look through input string one character at a time
      c=INSTR(i10:i10)
      if(ichar(c) == 9)then                ! test if character is a tab (ADE (ASCII Decimal Equivalent) of tab character is 9)
         IPOS = IPOS + (TABSIZE - (mod(IPOS-1,TABSIZE)))
      else                                 ! c is anything else other than a tab insert it in output string
         if(IPOS > lenout)then
            write(ERROR_UNIT,*)"*notabs* output string overflow"
            exit
         else
            OUTSTR(IPOS:IPOS)=c
            IPOS=IPOS+1
         endif
      endif
   enddo
   !
   ILEN=len_trim(OUTSTR(:IPOS))  ! trim trailing spaces
   return
   !
   end subroutine notabs

end module
