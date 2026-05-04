V35 :0x24 sfincs_partition
20 sfincs_partition.cuf S624 0
05/04/2026  11:54:25
use iso_c_binding public 0 indirect
use nvf_acc_common public 0 indirect
use cuda_runtime_api public 0 indirect
use cutensor_v2_types public 0 indirect
use cutensor_v2 public 0 indirect
use cutensorex_types public 0 indirect
use gpu_reduc_types public 0 indirect
use gpu_reductions public 0 indirect
use sort public 0 indirect
use cudafor_la public 0 direct
use mpi public 0 direct
use sfincs_data_device public 0 direct
use iso_fortran_env private
use sfincs_data private
enduse
D 58 26 941 8 940 7
D 67 26 944 8 943 7
D 76 26 941 8 940 7
D 97 26 1038 8 1037 7
D 378 26 1997 88 1996 7
D 384 23 7 1 11 705 0 0 0 0 0
 0 705 11 11 705 705
D 1493 26 8061 4 8060 3
D 1502 26 8074 4 8073 3
D 1511 26 8083 4 8082 3
D 1520 26 8152 4 8151 3
D 1529 26 8185 4 8184 3
D 1538 26 8244 4 8243 3
D 1547 26 8267 4 8266 3
D 1556 26 8284 4 8283 3
D 1565 26 8299 4 8298 3
D 1574 26 8304 4 8303 3
D 1583 26 8311 4 8310 3
D 1592 26 8318 4 8317 3
D 4033 23 6 1 11 11 0 0 0 0 0
 0 11 11 11 11 11
D 4036 23 6 1 11 11 0 0 0 0 0
 0 11 11 11 11 11
D 4039 23 6 1 11 2774 0 0 0 0 0
 0 2774 11 11 2774 2774
D 4042 23 6 1 11 2774 0 0 0 0 0
 0 2774 11 11 2774 2774
D 4045 23 6 1 11 2774 0 0 0 0 0
 0 2774 11 11 2774 2774
D 4048 23 6 1 11 2774 0 0 0 0 0
 0 2774 11 11 2774 2774
D 4051 23 6 1 11 700 0 0 0 0 0
 0 700 11 11 700 700
D 4054 23 6 1 11 700 0 0 0 0 0
 0 700 11 11 700 700
D 9234 23 9 1 11 10297 0 0 0 0 0
 0 10297 11 11 10297 10297
S 624 24 0 0 0 9 1 0 4986 10005 8000 A 0 0 0 0 B 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 sfincs_partition
S 630 23 0 0 0 6 20354 624 5057 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 npn_h
S 632 23 0 0 0 6 20355 624 5066 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 npuv_h
S 634 23 0 0 0 6 20560 624 5078 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 kcs_h
S 636 23 0 0 0 6 20572 624 5088 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 kfuv_h
S 638 23 0 0 0 6 20566 624 5100 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 kcuv_h
S 640 23 0 0 0 9 21215 624 5112 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 zs_h
S 642 23 0 0 0 9 21281 624 5120 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 zs0_h
S 644 23 0 0 0 9 21287 624 5130 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 zsderv_h
S 646 23 0 0 0 9 21233 624 5146 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 q_h
S 648 23 0 0 0 9 21239 624 5152 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 q0_h
S 650 23 0 0 0 9 21245 624 5160 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_h
S 652 23 0 0 0 9 21251 624 5168 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv0_h
S 654 23 0 0 0 9 20729 624 5178 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 zb_h
S 656 23 0 0 0 9 20735 624 5186 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 zbuv_h
S 658 23 0 0 0 9 20741 624 5198 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 zbuvmx_h
S 660 23 0 0 0 9 21197 624 5214 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 zsmax_h
S 662 23 0 0 0 6 21227 624 5228 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 maxzsm_h
S 664 23 0 0 0 9 21209 624 5244 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 qmax_h
S 666 23 0 0 0 9 21203 624 5256 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 vmax_h
S 668 23 0 0 0 9 21263 624 5268 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 twet_h
S 670 23 0 0 0 9 21221 624 5280 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 zsm_h
S 672 23 0 0 0 9 21257 624 5290 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 z_volume_h
S 674 23 0 0 0 9 20536 624 5310 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 z_flags_iref_h
S 676 23 0 0 0 9 20542 624 5338 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_flags_iref_h
S 678 23 0 0 0 9 20548 624 5368 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_flags_type_h
S 680 23 0 0 0 9 20554 624 5398 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_flags_dir_h
S 682 23 0 0 0 6 20578 624 5426 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 mask_adv_h
S 684 23 0 0 0 6 20880 624 5446 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 index_kcuv2_h
S 686 23 0 0 0 6 20892 624 5472 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 nmikcuv2_h
S 688 23 0 0 0 6 20886 624 5492 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 nmbkcuv2_h
S 690 23 0 0 0 6 20904 624 5512 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 ibkcuv2_h
S 692 23 0 0 0 9 21641 624 5530 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 zsb_h
S 694 23 0 0 0 9 21647 624 5540 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 zsb0_h
S 696 23 0 0 0 6 20898 624 5552 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 ibuvdir_h
S 698 23 0 0 0 9 20910 624 5570 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uvmean_h
S 700 23 0 0 0 9 21140 624 5586 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_uv_zmin_h
S 702 23 0 0 0 9 21146 624 5620 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_uv_zmax_h
S 704 23 0 0 0 9 21165 624 5654 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_uv_havg_h
S 706 23 0 0 0 9 21172 624 5688 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_uv_nrep_h
S 708 23 0 0 0 9 21179 624 5722 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_uv_pwet_h
S 710 23 0 0 0 9 21185 624 5756 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_uv_havg_zmax_h
S 712 23 0 0 0 9 21191 624 5800 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_uv_nrep_zmax_h
S 714 23 0 0 0 9 21158 624 5844 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_uv_fnfit_h
S 716 23 0 0 0 9 21152 624 5880 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_uv_navg_w_h
S 718 23 0 0 0 9 21115 624 5918 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_z_zmin_h
S 720 23 0 0 0 9 21121 624 5950 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_z_zmax_h
S 722 23 0 0 0 9 21134 624 5982 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_z_dep_h
S 724 23 0 0 0 9 21127 624 6012 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 subgrid_z_volmax_h
S 726 23 0 0 0 9 20434 624 6048 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 z_index_uv_md_h
S 728 23 0 0 0 9 20446 624 6078 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 z_index_uv_nd_h
S 730 23 0 0 0 9 20440 624 6108 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 z_index_uv_mu_h
S 732 23 0 0 0 9 20452 624 6138 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 z_index_uv_nu_h
S 734 23 0 0 0 9 20458 624 6168 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_index_z_nm_h
S 736 23 0 0 0 9 20464 624 6198 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_index_z_nmu_h
S 738 23 0 0 0 9 20476 624 6230 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_index_u_nmd_h
S 740 23 0 0 0 9 20470 624 6262 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_index_u_nmu_h
S 742 23 0 0 0 9 20488 624 6294 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_index_u_ndm_h
S 744 23 0 0 0 9 20482 624 6326 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_index_u_num_h
S 746 23 0 0 0 9 20494 624 6358 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_index_v_ndm_h
S 748 23 0 0 0 9 20506 624 6390 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_index_v_ndmu_h
S 750 23 0 0 0 9 20500 624 6424 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_index_v_nm_h
S 752 23 0 0 0 9 20512 624 6454 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 uv_index_v_nmu_h
S 754 23 0 0 0 6 22113 624 6486 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 nmindsrc_h
S 756 23 0 0 0 9 22107 624 6506 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 qtsrc_h
S 758 23 0 0 0 9 22119 624 6520 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 drainage_type_h
S 760 23 0 0 0 9 22126 624 6550 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 drainage_params_h
S 762 23 0 0 0 9 21016 624 6584 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 z_index_wavemaker_h
S 764 23 0 0 0 9 20980 624 6622 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 wavemaker_uvmean_h
S 766 23 0 0 0 9 20998 624 6658 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 wavemaker_nmd_h
S 768 23 0 0 0 9 20992 624 6688 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 wavemaker_nmu_h
S 770 23 0 0 0 9 21010 624 6718 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 wavemaker_ndm_h
S 772 23 0 0 0 9 21004 624 6748 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 wavemaker_num_h
S 774 23 0 0 0 9 22163 624 6778 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 structure_uv_index_h
S 776 23 0 0 0 9 22176 624 6818 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 structure_parameters_h
S 778 23 0 0 0 9 22169 624 6862 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 structure_type_h
S 780 23 0 0 0 9 22182 624 6894 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 structure_length_h
S 782 23 0 0 0 9 21515 624 6930 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 fwuv_h
S 784 23 0 0 0 9 21347 624 6942 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 tauwu_h
S 786 23 0 0 0 9 21353 624 6956 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 tauwv_h
S 788 23 0 0 0 9 21389 624 6970 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 tauwu0_h
S 790 23 0 0 0 9 21401 624 6986 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 tauwv0_h
S 792 23 0 0 0 9 21395 624 7002 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 tauwu1_h
S 794 23 0 0 0 9 21407 624 7018 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 tauwv1_h
S 796 23 0 0 0 9 21437 624 7034 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 windu_h
S 798 23 0 0 0 9 21443 624 7048 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 windv_h
S 800 23 0 0 0 9 21449 624 7062 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 windu0_h
S 802 23 0 0 0 9 21455 624 7078 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 windv0_h
S 804 23 0 0 0 9 21461 624 7094 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 windu1_h
S 806 23 0 0 0 9 21467 624 7110 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 windv1_h
S 808 23 0 0 0 9 21473 624 7126 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 windmax_h
S 810 23 0 0 0 9 21359 624 7144 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 patm_h
S 812 23 0 0 0 9 21413 624 7156 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 patm0_h
S 814 23 0 0 0 9 21419 624 7170 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 patm1_h
S 816 23 0 0 0 9 21653 624 7184 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 patmb_h
S 818 23 0 0 0 6 20368 624 7198 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 nmindbnd_h
S 820 23 0 0 0 9 21365 624 7218 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 prcp_h
S 822 23 0 0 0 9 21425 624 7230 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 prcp0_h
S 824 23 0 0 0 9 21431 624 7244 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 prcp1_h
S 826 23 0 0 0 9 21371 624 7258 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 cumprcp_h
S 828 23 0 0 0 6 21377 624 7276 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 netprcp_h
S 830 23 0 0 0 9 21293 624 7294 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 qext_h
S 832 23 0 0 0 9 20687 624 7306 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 dxminv_h
S 834 23 0 0 0 9 20633 624 7322 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 dxrinv_h
S 836 23 0 0 0 9 20639 624 7338 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 dyrinv_h
S 838 23 0 0 0 9 20693 624 7354 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 dxm2inv_h
S 840 23 0 0 0 9 20645 624 7372 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 dxr2inv_h
S 842 23 0 0 0 9 20651 624 7390 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 dyr2inv_h
S 844 23 0 0 0 9 20657 624 7408 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 dxrinvc_h
S 846 23 0 0 0 9 20663 624 7426 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 dyrinvc_h
S 848 23 0 0 0 9 20681 624 7444 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 dxm_h
S 850 23 0 0 0 9 20621 624 7454 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 dxrm_h
S 852 23 0 0 0 9 20627 624 7466 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 dyrm_h
S 854 23 0 0 0 9 20711 624 7478 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 cell_area_m2_h
S 856 23 0 0 0 9 20669 624 7506 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 cell_area_h
S 858 23 0 0 0 9 20747 624 7528 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 gn2uv_h
S 860 23 0 0 0 9 20874 624 7542 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 fcorio2d_h
S 862 23 0 0 0 9 20855 624 7562 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 storage_volume_h
S 864 23 0 0 0 6 20717 624 7594 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 nuvisc_h
S 866 23 0 0 0 9 20518 624 7610 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 cuv_index_uv_h
S 868 23 0 0 0 9 20524 624 7638 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 cuv_index_uv1_h
S 870 23 0 0 0 9 20530 624 7668 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 cuv_index_uv2_h
S 872 23 0 0 0 9 22249 624 7698 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 x73_h
S 874 23 0 0 0 9 21305 624 7708 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 gnapp2_h
S 876 23 0 0 0 9 21317 624 7724 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 timestep_analysis_required_timestep_h
S 878 23 0 0 0 9 21311 624 7798 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 timestep_analysis_average_required_timestep_h
S 880 23 0 0 0 9 21329 624 7888 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 timestep_analysis_times_wet_h
S 882 23 0 0 0 9 21323 624 7946 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 timestep_analysis_times_limiting_h
S 884 23 0 0 0 9 20753 624 8014 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 qinffield_h
S 886 23 0 0 0 9 20765 624 8036 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 qinfmap_h
S 888 23 0 0 0 9 21383 624 8054 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 cuminf_h
S 890 23 0 0 0 9 20584 624 8070 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 scs_rain_h
S 892 23 0 0 0 9 20783 624 8090 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 scs_se_h
S 894 23 0 0 0 9 20789 624 8106 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 scs_p1_h
S 896 23 0 0 0 9 20795 624 8122 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 scs_f1_h
S 898 23 0 0 0 9 20801 624 8138 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 scs_s1_h
S 900 23 0 0 0 9 20771 624 8154 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 rain_t1_h
S 902 23 0 0 0 6 20759 624 8172 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 ksfield_h
S 904 23 0 0 0 9 20807 624 8190 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 ga_head_h
S 906 23 0 0 0 9 20819 624 8208 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 ga_sigma_h
S 908 23 0 0 0 9 20813 624 8228 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 ga_sigma_max_h
S 910 23 0 0 0 9 20825 624 8256 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 ga_f_h
S 912 23 0 0 0 9 20831 624 8268 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 ga_lu_h
S 914 23 0 0 0 6 20777 624 8282 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 inf_kr_h
S 916 23 0 0 0 9 20849 624 8298 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 horton_kd_h
S 918 23 0 0 0 9 20837 624 8320 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 horton_fc_h
S 920 23 0 0 0 9 20843 624 8342 4 0 A 0 0 0 0 B 400000 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 horton_f0_h
S 923 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 4 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 924 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 925 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 8 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
R 940 25 7 iso_c_binding c_ptr
R 941 5 8 iso_c_binding val c_ptr
R 943 25 10 iso_c_binding c_funptr
R 944 5 11 iso_c_binding val c_funptr
R 978 6 45 iso_c_binding c_null_ptr$ac
R 980 6 47 iso_c_binding c_null_funptr$ac
R 981 26 48 iso_c_binding ==
R 983 26 50 iso_c_binding !=
S 1009 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 6 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1010 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 14 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1011 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 15 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1012 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 5 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1013 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 16 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1014 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 17 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1015 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 18 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1016 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 19 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1017 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 3 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1018 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 7 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1019 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 9 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1020 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 20 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1021 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 21 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1022 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 22 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1023 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 23 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1024 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 10 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1025 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 11 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1026 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 12 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1027 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 13 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1028 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 24 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1029 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 25 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1030 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 26 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1031 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 27 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
R 1037 25 6 nvf_acc_common c_devptr
R 1038 5 7 nvf_acc_common cptr c_devptr
R 1044 6 13 nvf_acc_common c_null_devptr$ac
R 1082 26 51 nvf_acc_common =
S 1142 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 28 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1143 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 31 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1144 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 32 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1145 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 35 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1146 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 37 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1228 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 -1 -1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1229 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 29 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1230 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 30 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1231 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 33 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1232 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 34 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1233 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 36 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1234 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 38 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1235 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 39 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1236 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 40 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1237 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 41 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1238 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 42 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1253 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 64 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1301 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 126 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1302 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 128 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1320 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 -1 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1321 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 256 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 1323 3 0 0 0 7 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 7
S 1326 3 0 0 0 7 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 8 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 7
R 1996 25 626 cuda_runtime_api cudapointerattributes
R 1997 5 627 cuda_runtime_api type cudapointerattributes
R 1998 5 628 cuda_runtime_api device cudapointerattributes
R 1999 5 629 cuda_runtime_api devptr cudapointerattributes
R 2000 5 630 cuda_runtime_api hostptr cudapointerattributes
R 2001 5 631 cuda_runtime_api reserved cudapointerattributes
S 8047 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 -1 -6 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 8048 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 -1 -4 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 8049 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 -1 -3 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 8050 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1024 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 8051 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 4096 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 8052 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 8192 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
S 8053 3 0 0 0 6 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 512 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6
R 8060 25 1 cutensor_v2_types cutensoralgo
R 8061 5 2 cutensor_v2_types algo cutensoralgo
R 8064 6 5 cutensor_v2_types cutensor_algo_default_patient$ac
R 8066 6 7 cutensor_v2_types cutensor_algo_gett$ac
R 8068 6 9 cutensor_v2_types cutensor_algo_tgett$ac
R 8070 6 11 cutensor_v2_types cutensor_algo_ttgt$ac
R 8072 6 13 cutensor_v2_types cutensor_algo_default$ac
R 8073 25 14 cutensor_v2_types cutensorworksizepreference
R 8074 5 15 cutensor_v2_types wksp cutensorworksizepreference
R 8077 6 18 cutensor_v2_types cutensor_workspace_min$ac
R 8079 6 20 cutensor_v2_types cutensor_workspace_default$ac
R 8081 6 22 cutensor_v2_types cutensor_workspace_max$ac
R 8082 25 23 cutensor_v2_types cutensoroperator
R 8083 5 24 cutensor_v2_types opno cutensoroperator
R 8086 6 27 cutensor_v2_types cutensor_op_identity$ac
R 8088 6 29 cutensor_v2_types cutensor_op_sqrt$ac
R 8090 6 31 cutensor_v2_types cutensor_op_relu$ac
R 8092 6 33 cutensor_v2_types cutensor_op_conj$ac
R 8094 6 35 cutensor_v2_types cutensor_op_rcp$ac
R 8096 6 37 cutensor_v2_types cutensor_op_sigmoid$ac
R 8098 6 39 cutensor_v2_types cutensor_op_tanh$ac
R 8100 6 41 cutensor_v2_types cutensor_op_exp$ac
R 8102 6 43 cutensor_v2_types cutensor_op_log$ac
R 8104 6 45 cutensor_v2_types cutensor_op_abs$ac
R 8106 6 47 cutensor_v2_types cutensor_op_neg$ac
R 8108 6 49 cutensor_v2_types cutensor_op_sin$ac
R 8110 6 51 cutensor_v2_types cutensor_op_cos$ac
R 8112 6 53 cutensor_v2_types cutensor_op_tan$ac
R 8114 6 55 cutensor_v2_types cutensor_op_sinh$ac
R 8116 6 57 cutensor_v2_types cutensor_op_cosh$ac
R 8118 6 59 cutensor_v2_types cutensor_op_asin$ac
R 8120 6 61 cutensor_v2_types cutensor_op_acos$ac
R 8122 6 63 cutensor_v2_types cutensor_op_atan$ac
R 8124 6 65 cutensor_v2_types cutensor_op_asinh$ac
R 8126 6 67 cutensor_v2_types cutensor_op_acosh$ac
R 8128 6 69 cutensor_v2_types cutensor_op_atanh$ac
R 8130 6 71 cutensor_v2_types cutensor_op_ceil$ac
R 8132 6 73 cutensor_v2_types cutensor_op_floor$ac
R 8134 6 75 cutensor_v2_types cutensor_op_mish$ac
R 8136 6 77 cutensor_v2_types cutensor_op_swish$ac
R 8138 6 79 cutensor_v2_types cutensor_op_soft_plus$ac
R 8140 6 81 cutensor_v2_types cutensor_op_soft_sign$ac
R 8142 6 83 cutensor_v2_types cutensor_op_add$ac
R 8144 6 85 cutensor_v2_types cutensor_op_mul$ac
R 8146 6 87 cutensor_v2_types cutensor_op_max$ac
R 8148 6 89 cutensor_v2_types cutensor_op_min$ac
R 8150 6 91 cutensor_v2_types cutensor_op_unknown$ac
R 8151 25 92 cutensor_v2_types cutensorstatus
R 8152 5 93 cutensor_v2_types stat cutensorstatus
R 8155 6 96 cutensor_v2_types cutensor_status_success$ac
R 8157 6 98 cutensor_v2_types cutensor_status_not_initialized$ac
R 8159 6 100 cutensor_v2_types cutensor_status_alloc_failed$ac
R 8161 6 102 cutensor_v2_types cutensor_status_invalid_value$ac
R 8163 6 104 cutensor_v2_types cutensor_status_arch_mismatch$ac
R 8165 6 106 cutensor_v2_types cutensor_status_mapping_error$ac
R 8167 6 108 cutensor_v2_types cutensor_status_execution_failed$ac
R 8169 6 110 cutensor_v2_types cutensor_status_internal_error$ac
R 8171 6 112 cutensor_v2_types cutensor_status_not_supported$ac
R 8173 6 114 cutensor_v2_types cutensor_status_license_error$ac
R 8175 6 116 cutensor_v2_types cutensor_status_cublas_error$ac
R 8177 6 118 cutensor_v2_types cutensor_status_cuda_error$ac
R 8179 6 120 cutensor_v2_types cutensor_status_insufficient_workspace$ac
R 8181 6 122 cutensor_v2_types cutensor_status_insufficient_driver$ac
R 8183 6 124 cutensor_v2_types cutensor_status_io_error$ac
R 8184 25 125 cutensor_v2_types cutensordatatype
R 8185 5 126 cutensor_v2_types cudadatatype cutensordatatype
R 8188 6 129 cutensor_v2_types cutensor_r_16f$ac
R 8190 6 131 cutensor_v2_types cutensor_c_16f$ac
R 8192 6 133 cutensor_v2_types cutensor_r_16bf$ac
R 8194 6 135 cutensor_v2_types cutensor_c_16bf$ac
R 8196 6 137 cutensor_v2_types cutensor_r_32f$ac
R 8198 6 139 cutensor_v2_types cutensor_c_32f$ac
R 8200 6 141 cutensor_v2_types cutensor_r_64f$ac
R 8202 6 143 cutensor_v2_types cutensor_c_64f$ac
R 8204 6 145 cutensor_v2_types cutensor_r_4i$ac
R 8206 6 147 cutensor_v2_types cutensor_c_4i$ac
R 8208 6 149 cutensor_v2_types cutensor_r_4u$ac
R 8210 6 151 cutensor_v2_types cutensor_c_4u$ac
R 8212 6 153 cutensor_v2_types cutensor_r_8i$ac
R 8214 6 155 cutensor_v2_types cutensor_c_8i$ac
R 8216 6 157 cutensor_v2_types cutensor_r_8u$ac
R 8218 6 159 cutensor_v2_types cutensor_c_8u$ac
R 8220 6 161 cutensor_v2_types cutensor_r_16i$ac
R 8222 6 163 cutensor_v2_types cutensor_c_16i$ac
R 8224 6 165 cutensor_v2_types cutensor_r_16u$ac
R 8226 6 167 cutensor_v2_types cutensor_c_16u$ac
R 8228 6 169 cutensor_v2_types cutensor_r_32i$ac
R 8230 6 171 cutensor_v2_types cutensor_c_32i$ac
R 8232 6 173 cutensor_v2_types cutensor_r_32u$ac
R 8234 6 175 cutensor_v2_types cutensor_c_32u$ac
R 8236 6 177 cutensor_v2_types cutensor_r_64i$ac
R 8238 6 179 cutensor_v2_types cutensor_c_64i$ac
R 8240 6 181 cutensor_v2_types cutensor_r_64u$ac
R 8242 6 183 cutensor_v2_types cutensor_c_64u$ac
R 8243 25 184 cutensor_v2_types cutensorcomputetype
R 8244 5 185 cutensor_v2_types type cutensorcomputetype
R 8247 6 188 cutensor_v2_types cutensor_compute_16f$ac
R 8249 6 190 cutensor_v2_types cutensor_compute_16bf$ac
R 8251 6 192 cutensor_v2_types cutensor_compute_tf32$ac
R 8253 6 194 cutensor_v2_types cutensor_compute_3xtf32$ac
R 8255 6 196 cutensor_v2_types cutensor_compute_32f$ac
R 8257 6 198 cutensor_v2_types cutensor_compute_64f$ac
R 8259 6 200 cutensor_v2_types cutensor_compute_8u$ac
R 8261 6 202 cutensor_v2_types cutensor_compute_8i$ac
R 8263 6 204 cutensor_v2_types cutensor_compute_32u$ac
R 8265 6 206 cutensor_v2_types cutensor_compute_32i$ac
R 8266 25 207 cutensor_v2_types cutensoroperationdescriptorattribute
R 8267 5 208 cutensor_v2_types attr cutensoroperationdescriptorattribute
R 8270 6 211 cutensor_v2_types cutensor_operation_descriptor_tag$ac
R 8272 6 213 cutensor_v2_types cutensor_operation_descriptor_scalar_type$ac
R 8274 6 215 cutensor_v2_types cutensor_operation_descriptor_flops$ac
R 8276 6 217 cutensor_v2_types cutensor_operation_descriptor_moved_bytes$ac
R 8278 6 219 cutensor_v2_types cutensor_operation_descriptor_padding_left$ac
R 8280 6 221 cutensor_v2_types cutensor_operation_descriptor_padding_right$ac
R 8282 6 223 cutensor_v2_types cutensor_operation_descriptor_padding_value$ac
R 8283 25 224 cutensor_v2_types cutensorplanpreferenceattribute
R 8284 5 225 cutensor_v2_types attr cutensorplanpreferenceattribute
R 8287 6 228 cutensor_v2_types cutensor_plan_preference_autotune_mode$ac
R 8289 6 230 cutensor_v2_types cutensor_plan_preference_cache_mode$ac
R 8291 6 232 cutensor_v2_types cutensor_plan_preference_incremental_count$ac
R 8293 6 234 cutensor_v2_types cutensor_plan_preference_algo$ac
R 8295 6 236 cutensor_v2_types cutensor_plan_preference_kernel_rank$ac
R 8297 6 238 cutensor_v2_types cutensor_plan_preference_jit$ac
R 8298 25 239 cutensor_v2_types cutensorplanattribute
R 8299 5 240 cutensor_v2_types attr cutensorplanattribute
R 8302 6 243 cutensor_v2_types cutensor_plan_required_workspace$ac
R 8303 25 244 cutensor_v2_types cutensorautotunemode
R 8304 5 245 cutensor_v2_types mode cutensorautotunemode
R 8307 6 248 cutensor_v2_types cutensor_autotune_mode_none$ac
R 8309 6 250 cutensor_v2_types cutensor_autotune_mode_incremental$ac
R 8310 25 251 cutensor_v2_types cutensorjitmode
R 8311 5 252 cutensor_v2_types mode cutensorjitmode
R 8314 6 255 cutensor_v2_types cutensor_jit_mode_none$ac
R 8316 6 257 cutensor_v2_types cutensor_jit_mode_default$ac
R 8317 25 258 cutensor_v2_types cutensorcachemode
R 8318 5 259 cutensor_v2_types mode cutensorcachemode
R 8321 6 262 cutensor_v2_types cutensor_cache_mode_none$ac
R 8323 6 264 cutensor_v2_types cutensor_cache_mode_pedantic$ac
S 9001 3 0 0 0 7 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 4 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 7
R 9439 26 436 gpu_reductions *
R 11736 7 3 iso_fortran_env character_kinds$ac
R 11758 7 25 iso_fortran_env integer_kinds$ac
R 11760 7 27 iso_fortran_env logical_kinds$ac
R 11762 7 29 iso_fortran_env real_kinds$ac
S 19692 3 0 0 0 7 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1000 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 7
S 19696 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1064631796 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19697 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067374871 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19698 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069321028 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19699 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071074247 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19700 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072693248 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19701 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073980899 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19702 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074727485 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19703 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075478266 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19704 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076208075 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19705 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076958855 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19706 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077655110 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19707 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078418473 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19708 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079135699 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19709 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079701930 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19710 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079785816 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19711 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079873896 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19712 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079915839 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19713 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079827759 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19714 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079622238 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19715 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079496409 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19716 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079374774 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19717 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079253139 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19718 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079018258 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19719 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078863069 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19720 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078712074 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19721 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078603022 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19722 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078456222 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19723 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078275867 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19724 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078133260 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19725 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077994848 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19726 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077822882 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19727 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077688664 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19728 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077525086 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19729 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077395063 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19730 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077235679 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19731 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077080490 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19732 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076807860 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19733 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076661060 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19734 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076514259 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19735 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076371653 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19736 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076233241 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19737 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076099023 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19738 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075964805 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19739 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075830587 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19740 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068037571 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19741 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070268940 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19742 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072332538 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19743 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074022842 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19744 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074974949 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19745 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075935445 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19746 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076866580 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19747 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078749823 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19748 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079743873 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19749 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080712757 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19750 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1081580978 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19751 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1081530647 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19752 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1081434178 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19753 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1081283183 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19754 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1081140576 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19755 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080947638 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19756 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080486265 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19757 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080263967 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19758 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080041669 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19759 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079538352 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19760 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079295082 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19761 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079056007 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19762 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078825320 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19763 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078565274 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19764 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078347170 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19765 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078099706 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19766 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077856436 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19767 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077428617 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19768 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077206319 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19769 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076988215 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19770 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076778500 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19771 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076572979 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19772 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076178715 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19773 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075989971 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19774 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075780256 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19775 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075599901 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19776 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075427934 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19777 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075255968 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19778 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075092390 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19779 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074928812 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19780 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074773623 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19781 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074597462 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19782 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074446467 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19783 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074303861 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19784 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065218998 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19785 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068079514 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19786 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070461878 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19787 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072659694 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19788 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074261918 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19789 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075331465 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19790 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078489776 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19791 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079580295 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19792 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1081887162 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19793 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1082273038 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19794 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1082138821 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19795 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1081631310 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19796 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080993776 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19797 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080666620 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19798 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080352047 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19799 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079999726 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19800 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079659987 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19801 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079332831 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19802 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077269234 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19803 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076719780 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19804 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076459733 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19805 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075755090 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19806 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075524403 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19807 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075306299 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19808 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074907841 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19809 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074706514 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19810 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074513576 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19811 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074324832 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19812 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074140283 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19813 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073964122 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19814 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073808933 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19815 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073540497 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19816 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073221730 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19817 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072902963 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19818 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072592585 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19819 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1064682127 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19820 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067827855 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19821 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070243774 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19822 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072491921 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19823 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074219975 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19824 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076430373 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19825 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077558641 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19826 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078674326 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19827 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1081090245 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19828 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1082245775 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19829 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1082382090 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19830 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1082218512 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19831 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1081480315 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19832 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079454466 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19833 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079097950 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19834 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077332148 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19835 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076690420 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19836 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076401013 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19837 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075574735 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19838 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075067224 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19839 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074840732 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19840 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074387747 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19841 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074161254 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19842 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073771184 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19843 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073397891 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19844 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073045570 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19845 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072005382 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19846 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071695004 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19847 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071367848 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19848 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070789034 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19849 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1063927153 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19850 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067391648 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19851 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069782401 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19852 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072038937 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19853 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074001871 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19854 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077361508 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19855 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1081044107 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19856 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1081186714 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19857 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080217829 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19858 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078028403 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19859 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077621555 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19860 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076895941 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19861 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076543619 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19862 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075885113 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19863 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075021087 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19864 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074752651 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19865 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074492604 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19866 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074240946 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19867 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073364337 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19868 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072970072 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19869 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072559030 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19870 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072164766 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19871 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071787278 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19872 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071426568 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19873 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071099412 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19874 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070763868 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19875 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070436712 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19876 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070117945 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19877 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069832733 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19878 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069539131 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19879 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069253919 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19880 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1063105069 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19881 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066863165 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19882 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069161644 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19883 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078166815 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19884 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079416717 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19885 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1082042352 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19886 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1081836831 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19887 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080175886 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19888 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078640771 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19889 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077755773 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19890 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076153549 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19891 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075805422 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19892 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075453100 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19893 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075138527 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19894 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074534547 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19895 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073725047 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19896 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073255285 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19897 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072802300 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19898 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072366092 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19899 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071913107 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19900 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071510454 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19901 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071132967 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19902 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070730314 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19903 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070377992 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19904 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070042448 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19905 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069715292 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19906 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069396525 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19907 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069094535 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19908 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068775768 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19909 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068498944 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19910 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068222120 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19911 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067962073 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19912 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1062115213 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19913 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066234020 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19914 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068431835 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19915 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070570930 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19916 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075352437 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19917 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080129749 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19918 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080809226 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19919 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1078527525 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19920 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076631699 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19921 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073846682 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19922 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073431446 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19923 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072399647 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19924 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071485288 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19925 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071040692 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19926 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070621262 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19927 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069857898 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19928 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069488800 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19929 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068817711 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19930 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068205343 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19931 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067903353 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19932 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067634917 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19933 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067358093 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19934 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067106435 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19935 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066846388 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19936 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1061108580 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19937 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065596486 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19938 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067651695 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19939 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069664961 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19940 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071636283 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19941 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073691492 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19942 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077889991 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19943 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075184665 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19944 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074794594 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19945 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074119311 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19946 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073288839 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19947 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072726802 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19948 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071669838 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19949 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071191687 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19950 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070302495 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19951 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069883064 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19952 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069463634 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19953 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068733825 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19954 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068389892 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19955 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068062736 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19956 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067743969 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19957 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067441979 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19958 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067156767 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19959 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066879943 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19960 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066611507 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19961 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066359849 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19962 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066124968 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19963 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065890087 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19964 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1060051616 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19965 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1064447246 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19966 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068691882 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19967 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072458367 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19968 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074081563 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19969 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077298594 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19970 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1080440127 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19971 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076262601 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19972 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074953978 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19973 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074555519 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19974 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074199003 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19975 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073322394 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19976 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072106045 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19977 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071577563 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19978 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070092780 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19979 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069639795 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19980 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069228753 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19981 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068457001 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19982 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067408425 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19983 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066796057 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19984 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066519233 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19985 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066250797 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19986 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065982362 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19987 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065730703 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19988 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065495822 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19989 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065168667 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19990 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1064732459 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19991 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1060018061 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19992 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1063037960 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19993 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067710415 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19994 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069446857 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19995 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071216853 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19996 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074345804 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19997 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077491532 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19998 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079957783 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 19999 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1079215391 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20000 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075675398 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20001 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075209830 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20002 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072869409 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20003 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072231875 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20004 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070512210 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20005 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070017282 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20006 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068666716 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20007 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068264063 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20008 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067886576 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20009 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067517477 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20010 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067173544 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20011 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066552787 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20012 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065965584 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20013 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065688760 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20014 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065428713 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20015 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065017672 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20016 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1064531132 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20017 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1064111702 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20018 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1063675494 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20019 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1063256064 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20020 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1062870188 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20021 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065084781 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20022 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066712170 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20023 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068289229 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20024 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069908230 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20025 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075625066 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20026 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074664571 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20027 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073179787 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20028 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071820833 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20029 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069564297 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20030 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068624773 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20031 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067785912 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20032 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067047715 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20033 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066695393 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20034 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066376626 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20035 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066049470 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20036 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065764258 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20037 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065487434 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20038 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1064816345 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20039 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1064464024 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20040 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1064162034 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20041 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1063826489 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20042 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1063541277 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20043 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1062970851 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20044 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066192077 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20045 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067139990 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20046 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068599607 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20047 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074425496 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20048 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075377603 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20049 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1077457977 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20050 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072936518 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20051 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072198320 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20052 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070872920 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20053 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069186810 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20054 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068708659 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20055 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068247286 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20056 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067802690 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20057 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066997383 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20058 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066728948 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20059 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066485678 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20060 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066041082 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20061 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065831367 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20062 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1065621651 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20063 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067072881 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20064 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070067614 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20065 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073146233 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20066 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1076925301 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20067 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075113361 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20068 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074102534 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20069 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073582440 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20070 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072768745 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20071 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071275573 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20072 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069421691 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20073 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068884820 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20074 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068473778 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20075 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1068138234 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20076 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1067249041 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20077 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1066980606 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20078 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070168277 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20079 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074861703 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20080 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074618434 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20081 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1071879553 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20082 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069589463 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20083 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1069203587 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20084 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1072298983 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20085 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073473389 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20086 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074404524 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20087 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1075281134 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20088 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074182226 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20089 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073615995 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20090 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070956806 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20091 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1070487044 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20092 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073649549 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20093 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074039620 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20094 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074282889 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20095 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1073884430 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
S 20096 3 0 0 0 9 1 1 0 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 1074685542 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 9
R 20354 6 258 sfincs_data np
R 20355 6 259 sfincs_data npuv
R 20368 7 272 sfincs_data nmindbnd
R 20434 7 338 sfincs_data z_index_uv_md
R 20440 7 344 sfincs_data z_index_uv_mu
R 20446 7 350 sfincs_data z_index_uv_nd
R 20452 7 356 sfincs_data z_index_uv_nu
R 20458 7 362 sfincs_data uv_index_z_nm
R 20464 7 368 sfincs_data uv_index_z_nmu
R 20470 7 374 sfincs_data uv_index_u_nmu
R 20476 7 380 sfincs_data uv_index_u_nmd
R 20482 7 386 sfincs_data uv_index_u_num
R 20488 7 392 sfincs_data uv_index_u_ndm
R 20494 7 398 sfincs_data uv_index_v_ndm
R 20500 7 404 sfincs_data uv_index_v_nm
R 20506 7 410 sfincs_data uv_index_v_ndmu
R 20512 7 416 sfincs_data uv_index_v_nmu
R 20518 7 422 sfincs_data cuv_index_uv
R 20524 7 428 sfincs_data cuv_index_uv1
R 20530 7 434 sfincs_data cuv_index_uv2
R 20536 7 440 sfincs_data z_flags_iref
R 20542 7 446 sfincs_data uv_flags_iref
R 20548 7 452 sfincs_data uv_flags_type
R 20554 7 458 sfincs_data uv_flags_dir
R 20560 7 464 sfincs_data kcs
R 20566 7 470 sfincs_data kcuv
R 20572 7 476 sfincs_data kfuv
R 20578 7 482 sfincs_data mask_adv
R 20584 7 488 sfincs_data scs_rain
R 20621 7 525 sfincs_data dxrm
R 20627 7 531 sfincs_data dyrm
R 20633 7 537 sfincs_data dxrinv
R 20639 7 543 sfincs_data dyrinv
R 20645 7 549 sfincs_data dxr2inv
R 20651 7 555 sfincs_data dyr2inv
R 20657 7 561 sfincs_data dxrinvc
R 20663 7 567 sfincs_data dyrinvc
R 20669 7 573 sfincs_data cell_area
R 20681 7 585 sfincs_data dxm
R 20687 7 591 sfincs_data dxminv
R 20693 7 597 sfincs_data dxm2inv
R 20711 7 615 sfincs_data cell_area_m2
R 20717 7 621 sfincs_data nuvisc
R 20729 7 633 sfincs_data zb
R 20735 7 639 sfincs_data zbuv
R 20741 7 645 sfincs_data zbuvmx
R 20747 7 651 sfincs_data gn2uv
R 20753 7 657 sfincs_data qinffield
R 20759 7 663 sfincs_data ksfield
R 20765 7 669 sfincs_data qinfmap
R 20771 7 675 sfincs_data rain_t1
R 20777 7 681 sfincs_data inf_kr
R 20783 7 687 sfincs_data scs_se
R 20789 7 693 sfincs_data scs_p1
R 20795 7 699 sfincs_data scs_f1
R 20801 7 705 sfincs_data scs_s1
R 20807 7 711 sfincs_data ga_head
R 20813 7 717 sfincs_data ga_sigma_max
R 20819 7 723 sfincs_data ga_sigma
R 20825 7 729 sfincs_data ga_f
R 20831 7 735 sfincs_data ga_lu
R 20837 7 741 sfincs_data horton_fc
R 20843 7 747 sfincs_data horton_f0
R 20849 7 753 sfincs_data horton_kd
R 20855 7 759 sfincs_data storage_volume
R 20874 7 778 sfincs_data fcorio2d
R 20880 7 784 sfincs_data index_kcuv2
R 20886 7 790 sfincs_data nmbkcuv2
R 20892 7 796 sfincs_data nmikcuv2
R 20898 7 802 sfincs_data ibuvdir
R 20904 7 808 sfincs_data ibkcuv2
R 20910 7 814 sfincs_data uvmean
R 20980 7 884 sfincs_data wavemaker_uvmean
R 20992 7 896 sfincs_data wavemaker_nmu
R 20998 7 902 sfincs_data wavemaker_nmd
R 21004 7 908 sfincs_data wavemaker_num
R 21010 7 914 sfincs_data wavemaker_ndm
R 21016 7 920 sfincs_data z_index_wavemaker
R 21115 7 1019 sfincs_data subgrid_z_zmin
R 21121 7 1025 sfincs_data subgrid_z_zmax
R 21127 7 1031 sfincs_data subgrid_z_volmax
R 21134 7 1038 sfincs_data subgrid_z_dep
R 21140 7 1044 sfincs_data subgrid_uv_zmin
R 21146 7 1050 sfincs_data subgrid_uv_zmax
R 21152 7 1056 sfincs_data subgrid_uv_navg_w
R 21158 7 1062 sfincs_data subgrid_uv_fnfit
R 21165 7 1069 sfincs_data subgrid_uv_havg
R 21172 7 1076 sfincs_data subgrid_uv_nrep
R 21179 7 1083 sfincs_data subgrid_uv_pwet
R 21185 7 1089 sfincs_data subgrid_uv_havg_zmax
R 21191 7 1095 sfincs_data subgrid_uv_nrep_zmax
R 21197 7 1101 sfincs_data zsmax
R 21203 7 1107 sfincs_data vmax
R 21209 7 1113 sfincs_data qmax
R 21215 7 1119 sfincs_data zs
R 21221 7 1125 sfincs_data zsm
R 21227 7 1131 sfincs_data maxzsm
R 21233 7 1137 sfincs_data q
R 21239 7 1143 sfincs_data q0
R 21245 7 1149 sfincs_data uv
R 21251 7 1155 sfincs_data uv0
R 21257 7 1161 sfincs_data z_volume
R 21263 7 1167 sfincs_data twet
R 21281 7 1185 sfincs_data zs0
R 21287 7 1191 sfincs_data zsderv
R 21293 7 1197 sfincs_data qext
R 21305 7 1209 sfincs_data gnapp2
R 21311 7 1215 sfincs_data timestep_analysis_average_required_timestep
R 21317 7 1221 sfincs_data timestep_analysis_required_timestep
R 21323 7 1227 sfincs_data timestep_analysis_times_limiting
R 21329 7 1233 sfincs_data timestep_analysis_times_wet
R 21347 7 1251 sfincs_data tauwu
R 21353 7 1257 sfincs_data tauwv
R 21359 7 1263 sfincs_data patm
R 21365 7 1269 sfincs_data prcp
R 21371 7 1275 sfincs_data cumprcp
R 21377 7 1281 sfincs_data netprcp
R 21383 7 1287 sfincs_data cuminf
R 21389 7 1293 sfincs_data tauwu0
R 21395 7 1299 sfincs_data tauwu1
R 21401 7 1305 sfincs_data tauwv0
R 21407 7 1311 sfincs_data tauwv1
R 21413 7 1317 sfincs_data patm0
R 21419 7 1323 sfincs_data patm1
R 21425 7 1329 sfincs_data prcp0
R 21431 7 1335 sfincs_data prcp1
R 21437 7 1341 sfincs_data windu
R 21443 7 1347 sfincs_data windv
R 21449 7 1353 sfincs_data windu0
R 21455 7 1359 sfincs_data windv0
R 21461 7 1365 sfincs_data windu1
R 21467 7 1371 sfincs_data windv1
R 21473 7 1377 sfincs_data windmax
R 21515 7 1419 sfincs_data fwuv
R 21641 7 1545 sfincs_data zsb
R 21647 7 1551 sfincs_data zsb0
R 21653 7 1557 sfincs_data patmb
R 22107 7 2011 sfincs_data qtsrc
R 22113 7 2017 sfincs_data nmindsrc
R 22119 7 2023 sfincs_data drainage_type
R 22126 7 2030 sfincs_data drainage_params
R 22163 7 2067 sfincs_data structure_uv_index
R 22169 7 2073 sfincs_data structure_type
R 22176 7 2080 sfincs_data structure_parameters
R 22182 7 2086 sfincs_data structure_length
R 22246 7 2150 sfincs_data z_c_0$ac
R 22249 7 2153 sfincs_data x73
S 22265 27 0 0 0 9 22270 624 132315 0 8000000 A 0 0 0 0 B 0 92 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 partition_and_localize
S 22266 27 0 0 0 9 22272 624 132338 0 8000000 A 0 0 0 0 B 0 92 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 device_finalize
S 22267 27 0 0 0 9 22274 624 132354 0 8000000 A 0 0 0 0 B 0 92 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 halo_exchange_zs
S 22268 27 0 0 0 9 22276 624 132371 0 8000000 A 0 0 0 0 B 0 92 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 halo_exchange_q_uv
S 22269 27 0 0 0 9 22278 624 132390 0 8000000 A 0 0 0 0 B 0 92 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 624 0 0 0 0 device_to_host_for_output
S 22270 23 5 0 0 0 22271 624 132315 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 partition_and_localize
S 22271 14 5 0 0 0 1 22270 132315 0 400000 A 0 0 0 0 B 0 0 0 0 0 0 0 10814 0 0 0 0 0 0 0 0 0 0 0 0 0 98 0 624 0 0 0 0 partition_and_localize partition_and_localize 
F 22271 0
S 22272 23 5 0 0 0 22273 624 132338 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 device_finalize
S 22273 14 5 0 0 0 1 22272 132338 0 400000 A 0 0 0 0 B 0 0 0 0 0 0 0 10815 0 0 0 0 0 0 0 0 0 0 0 0 0 300 0 624 0 0 0 0 device_finalize device_finalize 
F 22273 0
S 22274 23 5 0 0 0 22275 624 132354 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 halo_exchange_zs
S 22275 14 5 0 0 0 1 22274 132354 0 400000 A 0 0 0 0 B 0 0 0 0 0 0 0 10816 0 0 0 0 0 0 0 0 0 0 0 0 0 453 0 624 0 0 0 0 halo_exchange_zs halo_exchange_zs 
F 22275 0
S 22276 23 5 0 0 0 22277 624 132371 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 halo_exchange_q_uv
S 22277 14 5 0 0 0 1 22276 132371 0 400000 A 0 0 0 0 B 0 0 0 0 0 0 0 10817 0 0 0 0 0 0 0 0 0 0 0 0 0 457 0 624 0 0 0 0 halo_exchange_q_uv halo_exchange_q_uv 
F 22277 0
S 22278 23 5 0 0 0 22279 624 132390 0 0 A 0 0 0 0 B 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 device_to_host_for_output
S 22279 14 5 0 0 0 1 22278 132390 0 400000 A 0 0 0 0 B 0 0 0 0 0 0 0 10818 0 0 0 0 0 0 0 0 0 0 0 0 0 461 0 624 0 0 0 0 device_to_host_for_output device_to_host_for_output 
F 22279 0
A 13 2 0 0 0 6 923 0 0 0 13 0 0 0 0 0 0 0 0 0 0 0
A 15 2 0 0 0 6 924 0 0 0 15 0 0 0 0 0 0 0 0 0 0 0
A 17 2 0 0 0 6 925 0 0 0 17 0 0 0 0 0 0 0 0 0 0 0
A 68 1 0 0 0 58 978 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 71 1 0 0 0 67 980 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 78 2 0 0 0 6 1009 0 0 0 78 0 0 0 0 0 0 0 0 0 0 0
A 80 2 0 0 0 6 1010 0 0 0 80 0 0 0 0 0 0 0 0 0 0 0
A 82 2 0 0 0 6 1011 0 0 0 82 0 0 0 0 0 0 0 0 0 0 0
A 87 2 0 0 0 6 1012 0 0 0 87 0 0 0 0 0 0 0 0 0 0 0
A 89 2 0 0 0 6 1013 0 0 0 89 0 0 0 0 0 0 0 0 0 0 0
A 91 2 0 0 0 6 1014 0 0 0 91 0 0 0 0 0 0 0 0 0 0 0
A 93 2 0 0 0 6 1015 0 0 0 93 0 0 0 0 0 0 0 0 0 0 0
A 95 2 0 0 0 6 1016 0 0 0 95 0 0 0 0 0 0 0 0 0 0 0
A 97 2 0 0 0 6 1017 0 0 0 97 0 0 0 0 0 0 0 0 0 0 0
A 99 2 0 0 0 6 1018 0 0 0 99 0 0 0 0 0 0 0 0 0 0 0
A 102 2 0 0 0 6 1019 0 0 0 102 0 0 0 0 0 0 0 0 0 0 0
A 104 2 0 0 0 6 1020 0 0 0 104 0 0 0 0 0 0 0 0 0 0 0
A 106 2 0 0 0 6 1021 0 0 0 106 0 0 0 0 0 0 0 0 0 0 0
A 108 2 0 0 0 6 1022 0 0 0 108 0 0 0 0 0 0 0 0 0 0 0
A 110 2 0 0 0 6 1023 0 0 0 110 0 0 0 0 0 0 0 0 0 0 0
A 112 2 0 0 0 6 1024 0 0 0 112 0 0 0 0 0 0 0 0 0 0 0
A 114 2 0 0 0 6 1025 0 0 0 114 0 0 0 0 0 0 0 0 0 0 0
A 116 2 0 0 0 6 1026 0 0 0 116 0 0 0 0 0 0 0 0 0 0 0
A 118 2 0 0 0 6 1027 0 0 0 118 0 0 0 0 0 0 0 0 0 0 0
A 120 2 0 0 0 6 1028 0 0 0 120 0 0 0 0 0 0 0 0 0 0 0
A 122 2 0 0 0 6 1029 0 0 0 122 0 0 0 0 0 0 0 0 0 0 0
A 124 2 0 0 0 6 1030 0 0 0 124 0 0 0 0 0 0 0 0 0 0 0
A 126 2 0 0 0 6 1031 0 0 0 126 0 0 0 0 0 0 0 0 0 0 0
A 141 1 0 0 0 97 1044 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 142 2 0 0 128 6 1229 0 0 0 142 0 0 0 0 0 0 0 0 0 0 0
A 143 2 0 0 0 6 1232 0 0 0 143 0 0 0 0 0 0 0 0 0 0 0
A 144 2 0 0 0 6 1142 0 0 0 144 0 0 0 0 0 0 0 0 0 0 0
A 147 2 0 0 0 6 1238 0 0 0 147 0 0 0 0 0 0 0 0 0 0 0
A 148 2 0 0 0 6 1233 0 0 0 148 0 0 0 0 0 0 0 0 0 0 0
A 175 2 0 0 0 6 1143 0 0 0 175 0 0 0 0 0 0 0 0 0 0 0
A 177 2 0 0 0 6 1144 0 0 0 177 0 0 0 0 0 0 0 0 0 0 0
A 179 2 0 0 0 6 1145 0 0 0 179 0 0 0 0 0 0 0 0 0 0 0
A 181 2 0 0 0 6 1146 0 0 0 181 0 0 0 0 0 0 0 0 0 0 0
A 364 2 0 0 127 6 1228 0 0 0 364 0 0 0 0 0 0 0 0 0 0 0
A 438 2 0 0 129 6 1230 0 0 0 438 0 0 0 0 0 0 0 0 0 0 0
A 442 2 0 0 0 6 1231 0 0 0 442 0 0 0 0 0 0 0 0 0 0 0
A 448 2 0 0 0 6 1234 0 0 0 448 0 0 0 0 0 0 0 0 0 0 0
A 450 2 0 0 0 6 1235 0 0 0 450 0 0 0 0 0 0 0 0 0 0 0
A 452 2 0 0 0 6 1236 0 0 0 452 0 0 0 0 0 0 0 0 0 0 0
A 454 2 0 0 0 6 1237 0 0 0 454 0 0 0 0 0 0 0 0 0 0 0
A 490 2 0 0 0 6 1253 0 0 0 490 0 0 0 0 0 0 0 0 0 0 0
A 594 2 0 0 0 6 1301 0 0 0 594 0 0 0 0 0 0 0 0 0 0 0
A 597 2 0 0 0 6 1302 0 0 0 597 0 0 0 0 0 0 0 0 0 0 0
A 673 2 0 0 0 6 1320 0 0 0 673 0 0 0 0 0 0 0 0 0 0 0
A 700 2 0 0 0 7 1323 0 0 0 700 0 0 0 0 0 0 0 0 0 0 0
A 701 2 0 0 0 6 1321 0 0 0 701 0 0 0 0 0 0 0 0 0 0 0
A 705 2 0 0 0 7 1326 0 0 0 705 0 0 0 0 0 0 0 0 0 0 0
A 1702 2 0 0 1199 6 8047 0 0 0 1702 0 0 0 0 0 0 0 0 0 0 0
A 1706 2 0 0 1201 6 8048 0 0 0 1706 0 0 0 0 0 0 0 0 0 0 0
A 1710 2 0 0 0 6 8049 0 0 0 1710 0 0 0 0 0 0 0 0 0 0 0
A 1960 2 0 0 0 6 8050 0 0 0 1960 0 0 0 0 0 0 0 0 0 0 0
A 1964 2 0 0 0 6 8051 0 0 0 1964 0 0 0 0 0 0 0 0 0 0 0
A 1968 2 0 0 0 6 8052 0 0 0 1968 0 0 0 0 0 0 0 0 0 0 0
A 1987 2 0 0 0 6 8053 0 0 0 1987 0 0 0 0 0 0 0 0 0 0 0
A 2055 1 0 0 0 1493 8064 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2058 1 0 0 0 1493 8066 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2061 1 0 0 1073 1493 8068 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2064 1 0 0 0 1493 8070 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2067 1 0 0 0 1493 8072 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2070 1 0 0 0 1502 8077 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2073 1 0 0 0 1502 8079 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2076 1 0 0 0 1502 8081 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2079 1 0 0 0 1511 8086 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2082 1 0 0 0 1511 8088 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2085 1 0 0 906 1511 8090 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2088 1 0 0 0 1511 8092 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2091 1 0 0 0 1511 8094 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2094 1 0 0 0 1511 8096 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2097 1 0 0 0 1511 8098 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2100 1 0 0 0 1511 8100 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2103 1 0 0 0 1511 8102 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2106 1 0 0 0 1511 8104 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2109 1 0 0 0 1511 8106 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2112 1 0 0 0 1511 8108 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2115 1 0 0 0 1511 8110 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2118 1 0 0 0 1511 8112 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2121 1 0 0 0 1511 8114 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2124 1 0 0 0 1511 8116 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2127 1 0 0 0 1511 8118 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2130 1 0 0 0 1511 8120 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2133 1 0 0 0 1511 8122 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2136 1 0 0 0 1511 8124 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2139 1 0 0 0 1511 8126 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2142 1 0 0 0 1511 8128 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2145 1 0 0 0 1511 8130 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2148 1 0 0 0 1511 8132 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2151 1 0 0 0 1511 8134 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2154 1 0 0 0 1511 8136 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2157 1 0 0 0 1511 8138 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2160 1 0 0 0 1511 8140 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2163 1 0 0 0 1511 8142 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2166 1 0 0 0 1511 8144 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2169 1 0 0 2029 1511 8146 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2172 1 0 0 0 1511 8148 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2175 1 0 0 0 1511 8150 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2178 1 0 0 0 1520 8155 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2181 1 0 0 0 1520 8157 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2184 1 0 0 0 1520 8159 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2187 1 0 0 0 1520 8161 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2190 1 0 0 0 1520 8163 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2193 1 0 0 0 1520 8165 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2196 1 0 0 0 1520 8167 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2199 1 0 0 0 1520 8169 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2202 1 0 0 0 1520 8171 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2205 1 0 0 0 1520 8173 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2208 1 0 0 0 1520 8175 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2211 1 0 0 0 1520 8177 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2214 1 0 0 0 1520 8179 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2217 1 0 0 0 1520 8181 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2220 1 0 0 0 1520 8183 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2223 1 0 0 0 1529 8188 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2226 1 0 0 0 1529 8190 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2229 1 0 0 0 1529 8192 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2232 1 0 0 0 1529 8194 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2235 1 0 0 0 1529 8196 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2238 1 0 0 0 1529 8198 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2241 1 0 0 0 1529 8200 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2244 1 0 0 0 1529 8202 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2247 1 0 0 0 1529 8204 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2250 1 0 0 0 1529 8206 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2253 1 0 0 0 1529 8208 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2256 1 0 0 0 1529 8210 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2259 1 0 0 0 1529 8212 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2262 1 0 0 0 1529 8214 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2265 1 0 0 0 1529 8216 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2268 1 0 0 0 1529 8218 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2271 1 0 0 0 1529 8220 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2274 1 0 0 0 1529 8222 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2277 1 0 0 0 1529 8224 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2280 1 0 0 0 1529 8226 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2283 1 0 0 0 1529 8228 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2286 1 0 0 0 1529 8230 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2289 1 0 0 1053 1529 8232 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2292 1 0 0 0 1529 8234 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2295 1 0 0 0 1529 8236 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2298 1 0 0 0 1529 8238 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2301 1 0 0 0 1529 8240 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2304 1 0 0 0 1529 8242 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2307 1 0 0 0 1538 8247 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2310 1 0 0 0 1538 8249 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2313 1 0 0 712 1538 8251 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2316 1 0 0 0 1538 8253 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2319 1 0 0 0 1538 8255 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2322 1 0 0 0 1538 8257 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2325 1 0 0 0 1538 8259 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2328 1 0 0 0 1538 8261 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2331 1 0 0 0 1538 8263 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2334 1 0 0 0 1538 8265 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2337 1 0 0 0 1547 8270 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2340 1 0 0 0 1547 8272 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2343 1 0 0 0 1547 8274 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2346 1 0 0 0 1547 8276 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2349 1 0 0 0 1547 8278 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2352 1 0 0 0 1547 8280 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2355 1 0 0 0 1547 8282 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2358 1 0 0 2148 1556 8287 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2361 1 0 0 2151 1556 8289 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2364 1 0 0 2154 1556 8291 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2367 1 0 0 2157 1556 8293 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2370 1 0 0 2160 1556 8295 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2373 1 0 0 2163 1556 8297 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2376 1 0 0 1821 1565 8302 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2379 1 0 0 0 1574 8307 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2382 1 0 0 0 1574 8309 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2385 1 0 0 0 1583 8314 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2388 1 0 0 0 1583 8316 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2391 1 0 0 0 1592 8321 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2394 1 0 0 0 1592 8323 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 2774 2 0 0 0 7 9001 0 0 0 2774 0 0 0 0 0 0 0 0 0 0 0
A 4323 1 0 7 0 4033 11736 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 4329 1 0 9 0 4039 11758 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 4335 1 0 9 1226 4045 11760 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 4339 1 0 11 0 4051 11762 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
A 6632 2 0 0 3618 9 19696 0 0 0 6632 0 0 0 0 0 0 0 0 0 0 0
A 6633 2 0 0 3621 9 19697 0 0 0 6633 0 0 0 0 0 0 0 0 0 0 0
A 6634 2 0 0 6112 9 19698 0 0 0 6634 0 0 0 0 0 0 0 0 0 0 0
A 6635 2 0 0 6419 9 19699 0 0 0 6635 0 0 0 0 0 0 0 0 0 0 0
A 6636 2 0 0 3630 9 19700 0 0 0 6636 0 0 0 0 0 0 0 0 0 0 0
A 6637 2 0 0 3633 9 19701 0 0 0 6637 0 0 0 0 0 0 0 0 0 0 0
A 6638 2 0 0 6288 9 19702 0 0 0 6638 0 0 0 0 0 0 0 0 0 0 0
A 6639 2 0 0 3636 9 19703 0 0 0 6639 0 0 0 0 0 0 0 0 0 0 0
A 6640 2 0 0 3635 9 19704 0 0 0 6640 0 0 0 0 0 0 0 0 0 0 0
A 6641 2 0 0 3639 9 19705 0 0 0 6641 0 0 0 0 0 0 0 0 0 0 0
A 6642 2 0 0 3638 9 19706 0 0 0 6642 0 0 0 0 0 0 0 0 0 0 0
A 6643 2 0 0 3642 9 19707 0 0 0 6643 0 0 0 0 0 0 0 0 0 0 0
A 6644 2 0 0 6427 9 19708 0 0 0 6644 0 0 0 0 0 0 0 0 0 0 0
A 6645 2 0 0 6152 9 19709 0 0 0 6645 0 0 0 0 0 0 0 0 0 0 0
A 6646 2 0 0 3644 9 19710 0 0 0 6646 0 0 0 0 0 0 0 0 0 0 0
A 6647 2 0 0 3648 9 19711 0 0 0 6647 0 0 0 0 0 0 0 0 0 0 0
A 6648 2 0 0 3647 9 19712 0 0 0 6648 0 0 0 0 0 0 0 0 0 0 0
A 6649 2 0 0 3650 9 19713 0 0 0 6649 0 0 0 0 0 0 0 0 0 0 0
A 6650 2 0 0 3629 9 19714 0 0 0 6650 0 0 0 0 0 0 0 0 0 0 0
A 6651 2 0 0 3631 9 19715 0 0 0 6651 0 0 0 0 0 0 0 0 0 0 0
A 6652 2 0 0 3634 9 19716 0 0 0 6652 0 0 0 0 0 0 0 0 0 0 0
A 6653 2 0 0 3637 9 19717 0 0 0 6653 0 0 0 0 0 0 0 0 0 0 0
A 6654 2 0 0 3640 9 19718 0 0 0 6654 0 0 0 0 0 0 0 0 0 0 0
A 6655 2 0 0 3643 9 19719 0 0 0 6655 0 0 0 0 0 0 0 0 0 0 0
A 6656 2 0 0 3646 9 19720 0 0 0 6656 0 0 0 0 0 0 0 0 0 0 0
A 6657 2 0 0 5706 9 19721 0 0 0 6657 0 0 0 0 0 0 0 0 0 0 0
A 6658 2 0 0 0 9 19722 0 0 0 6658 0 0 0 0 0 0 0 0 0 0 0
A 6659 2 0 0 0 9 19723 0 0 0 6659 0 0 0 0 0 0 0 0 0 0 0
A 6660 2 0 0 0 9 19724 0 0 0 6660 0 0 0 0 0 0 0 0 0 0 0
A 6661 2 0 0 2032 9 19725 0 0 0 6661 0 0 0 0 0 0 0 0 0 0 0
A 6662 2 0 0 2379 9 19726 0 0 0 6662 0 0 0 0 0 0 0 0 0 0 0
A 6663 2 0 0 2035 9 19727 0 0 0 6663 0 0 0 0 0 0 0 0 0 0 0
A 6664 2 0 0 5701 9 19728 0 0 0 6664 0 0 0 0 0 0 0 0 0 0 0
A 6665 2 0 0 3652 9 19729 0 0 0 6665 0 0 0 0 0 0 0 0 0 0 0
A 6666 2 0 0 3654 9 19730 0 0 0 6666 0 0 0 0 0 0 0 0 0 0 0
A 6667 2 0 0 3651 9 19731 0 0 0 6667 0 0 0 0 0 0 0 0 0 0 0
A 6668 2 0 0 3653 9 19732 0 0 0 6668 0 0 0 0 0 0 0 0 0 0 0
A 6669 2 0 0 3656 9 19733 0 0 0 6669 0 0 0 0 0 0 0 0 0 0 0
A 6670 2 0 0 5709 9 19734 0 0 0 6670 0 0 0 0 0 0 0 0 0 0 0
A 6671 2 0 0 3655 9 19735 0 0 0 6671 0 0 0 0 0 0 0 0 0 0 0
A 6672 2 0 0 3657 9 19736 0 0 0 6672 0 0 0 0 0 0 0 0 0 0 0
A 6673 2 0 0 0 9 19737 0 0 0 6673 0 0 0 0 0 0 0 0 0 0 0
A 6674 2 0 0 0 9 19738 0 0 0 6674 0 0 0 0 0 0 0 0 0 0 0
A 6675 2 0 0 0 9 19739 0 0 0 6675 0 0 0 0 0 0 0 0 0 0 0
A 6676 2 0 0 2585 9 614 0 0 0 6676 0 0 0 0 0 0 0 0 0 0 0
A 6677 2 0 0 0 9 19740 0 0 0 6677 0 0 0 0 0 0 0 0 0 0 0
A 6678 2 0 0 0 9 19741 0 0 0 6678 0 0 0 0 0 0 0 0 0 0 0
A 6679 2 0 0 0 9 19742 0 0 0 6679 0 0 0 0 0 0 0 0 0 0 0
A 6680 2 0 0 0 9 19743 0 0 0 6680 0 0 0 0 0 0 0 0 0 0 0
A 6681 2 0 0 5055 9 19744 0 0 0 6681 0 0 0 0 0 0 0 0 0 0 0
A 6682 2 0 0 3663 9 19745 0 0 0 6682 0 0 0 0 0 0 0 0 0 0 0
A 6683 2 0 0 3662 9 19746 0 0 0 6683 0 0 0 0 0 0 0 0 0 0 0
A 6684 2 0 0 3665 9 19747 0 0 0 6684 0 0 0 0 0 0 0 0 0 0 0
A 6685 2 0 0 3659 9 19748 0 0 0 6685 0 0 0 0 0 0 0 0 0 0 0
A 6686 2 0 0 3661 9 19749 0 0 0 6686 0 0 0 0 0 0 0 0 0 0 0
A 6687 2 0 0 3664 9 19750 0 0 0 6687 0 0 0 0 0 0 0 0 0 0 0
A 6688 2 0 0 3667 9 19751 0 0 0 6688 0 0 0 0 0 0 0 0 0 0 0
A 6689 2 0 0 3670 9 19752 0 0 0 6689 0 0 0 0 0 0 0 0 0 0 0
A 6690 2 0 0 3669 9 19753 0 0 0 6690 0 0 0 0 0 0 0 0 0 0 0
A 6691 2 0 0 3672 9 19754 0 0 0 6691 0 0 0 0 0 0 0 0 0 0 0
A 6692 2 0 0 3666 9 19755 0 0 0 6692 0 0 0 0 0 0 0 0 0 0 0
A 6693 2 0 0 5056 9 19756 0 0 0 6693 0 0 0 0 0 0 0 0 0 0 0
A 6694 2 0 0 3671 9 19757 0 0 0 6694 0 0 0 0 0 0 0 0 0 0 0
A 6695 2 0 0 0 9 19758 0 0 0 6695 0 0 0 0 0 0 0 0 0 0 0
A 6696 2 0 0 0 9 19759 0 0 0 6696 0 0 0 0 0 0 0 0 0 0 0
A 6697 2 0 0 0 9 19760 0 0 0 6697 0 0 0 0 0 0 0 0 0 0 0
A 6698 2 0 0 0 9 19761 0 0 0 6698 0 0 0 0 0 0 0 0 0 0 0
A 6699 2 0 0 0 9 19762 0 0 0 6699 0 0 0 0 0 0 0 0 0 0 0
A 6700 2 0 0 0 9 19763 0 0 0 6700 0 0 0 0 0 0 0 0 0 0 0
A 6701 2 0 0 0 9 19764 0 0 0 6701 0 0 0 0 0 0 0 0 0 0 0
A 6702 2 0 0 3674 9 19765 0 0 0 6702 0 0 0 0 0 0 0 0 0 0 0
A 6703 2 0 0 3677 9 19766 0 0 0 6703 0 0 0 0 0 0 0 0 0 0 0
A 6704 2 0 0 3676 9 19767 0 0 0 6704 0 0 0 0 0 0 0 0 0 0 0
A 6705 2 0 0 3680 9 19768 0 0 0 6705 0 0 0 0 0 0 0 0 0 0 0
A 6706 2 0 0 6613 9 19769 0 0 0 6706 0 0 0 0 0 0 0 0 0 0 0
A 6707 2 0 0 3682 9 19770 0 0 0 6707 0 0 0 0 0 0 0 0 0 0 0
A 6708 2 0 0 3673 9 19771 0 0 0 6708 0 0 0 0 0 0 0 0 0 0 0
A 6709 2 0 0 3675 9 19772 0 0 0 6709 0 0 0 0 0 0 0 0 0 0 0
A 6710 2 0 0 3678 9 19773 0 0 0 6710 0 0 0 0 0 0 0 0 0 0 0
A 6711 2 0 0 3681 9 19774 0 0 0 6711 0 0 0 0 0 0 0 0 0 0 0
A 6712 2 0 0 3684 9 19775 0 0 0 6712 0 0 0 0 0 0 0 0 0 0 0
A 6713 2 0 0 6477 9 19776 0 0 0 6713 0 0 0 0 0 0 0 0 0 0 0
A 6714 2 0 0 3686 9 19777 0 0 0 6714 0 0 0 0 0 0 0 0 0 0 0
A 6715 2 0 0 5057 9 19778 0 0 0 6715 0 0 0 0 0 0 0 0 0 0 0
A 6716 2 0 0 3689 9 19779 0 0 0 6716 0 0 0 0 0 0 0 0 0 0 0
A 6717 2 0 0 3692 9 19780 0 0 0 6717 0 0 0 0 0 0 0 0 0 0 0
A 6718 2 0 0 3683 9 19781 0 0 0 6718 0 0 0 0 0 0 0 0 0 0 0
A 6719 2 0 0 3685 9 19782 0 0 0 6719 0 0 0 0 0 0 0 0 0 0 0
A 6720 2 0 0 3688 9 19783 0 0 0 6720 0 0 0 0 0 0 0 0 0 0 0
A 6721 2 0 0 3691 9 19784 0 0 0 6721 0 0 0 0 0 0 0 0 0 0 0
A 6722 2 0 0 0 9 19785 0 0 0 6722 0 0 0 0 0 0 0 0 0 0 0
A 6723 2 0 0 0 9 19786 0 0 0 6723 0 0 0 0 0 0 0 0 0 0 0
A 6724 2 0 0 0 9 19787 0 0 0 6724 0 0 0 0 0 0 0 0 0 0 0
A 6725 2 0 0 0 9 19788 0 0 0 6725 0 0 0 0 0 0 0 0 0 0 0
A 6726 2 0 0 0 9 19789 0 0 0 6726 0 0 0 0 0 0 0 0 0 0 0
A 6727 2 0 0 0 9 19790 0 0 0 6727 0 0 0 0 0 0 0 0 0 0 0
A 6728 2 0 0 0 9 19791 0 0 0 6728 0 0 0 0 0 0 0 0 0 0 0
A 6729 2 0 0 5058 9 19792 0 0 0 6729 0 0 0 0 0 0 0 0 0 0 0
A 6730 2 0 0 3697 9 19793 0 0 0 6730 0 0 0 0 0 0 0 0 0 0 0
A 6731 2 0 0 3696 9 19794 0 0 0 6731 0 0 0 0 0 0 0 0 0 0 0
A 6732 2 0 0 3700 9 19795 0 0 0 6732 0 0 0 0 0 0 0 0 0 0 0
A 6733 2 0 0 3699 9 19796 0 0 0 6733 0 0 0 0 0 0 0 0 0 0 0
A 6734 2 0 0 3703 9 19797 0 0 0 6734 0 0 0 0 0 0 0 0 0 0 0
A 6735 2 0 0 3702 9 19798 0 0 0 6735 0 0 0 0 0 0 0 0 0 0 0
A 6736 2 0 0 3705 9 19799 0 0 0 6736 0 0 0 0 0 0 0 0 0 0 0
A 6737 2 0 0 6347 9 19800 0 0 0 6737 0 0 0 0 0 0 0 0 0 0 0
A 6738 2 0 0 3695 9 19801 0 0 0 6738 0 0 0 0 0 0 0 0 0 0 0
A 6739 2 0 0 3698 9 19802 0 0 0 6739 0 0 0 0 0 0 0 0 0 0 0
A 6740 2 0 0 5059 9 19803 0 0 0 6740 0 0 0 0 0 0 0 0 0 0 0
A 6741 2 0 0 3704 9 19804 0 0 0 6741 0 0 0 0 0 0 0 0 0 0 0
A 6742 2 0 0 3707 9 19805 0 0 0 6742 0 0 0 0 0 0 0 0 0 0 0
A 6743 2 0 0 6355 9 19806 0 0 0 6743 0 0 0 0 0 0 0 0 0 0 0
A 6744 2 0 0 3709 9 19807 0 0 0 6744 0 0 0 0 0 0 0 0 0 0 0
A 6745 2 0 0 3713 9 19808 0 0 0 6745 0 0 0 0 0 0 0 0 0 0 0
A 6746 2 0 0 3712 9 19809 0 0 0 6746 0 0 0 0 0 0 0 0 0 0 0
A 6747 2 0 0 3716 9 19810 0 0 0 6747 0 0 0 0 0 0 0 0 0 0 0
A 6748 2 0 0 3715 9 19811 0 0 0 6748 0 0 0 0 0 0 0 0 0 0 0
A 6749 2 0 0 6363 9 19812 0 0 0 6749 0 0 0 0 0 0 0 0 0 0 0
A 6750 2 0 0 3706 9 19813 0 0 0 6750 0 0 0 0 0 0 0 0 0 0 0
A 6751 2 0 0 5060 9 19814 0 0 0 6751 0 0 0 0 0 0 0 0 0 0 0
A 6752 2 0 0 3711 9 19815 0 0 0 6752 0 0 0 0 0 0 0 0 0 0 0
A 6753 2 0 0 3714 9 19816 0 0 0 6753 0 0 0 0 0 0 0 0 0 0 0
A 6754 2 0 0 3717 9 19817 0 0 0 6754 0 0 0 0 0 0 0 0 0 0 0
A 6755 2 0 0 0 9 19818 0 0 0 6755 0 0 0 0 0 0 0 0 0 0 0
A 6756 2 0 0 0 9 19819 0 0 0 6756 0 0 0 0 0 0 0 0 0 0 0
A 6757 2 0 0 1597 9 19820 0 0 0 6757 0 0 0 0 0 0 0 0 0 0 0
A 6758 2 0 0 0 9 19821 0 0 0 6758 0 0 0 0 0 0 0 0 0 0 0
A 6759 2 0 0 0 9 19822 0 0 0 6759 0 0 0 0 0 0 0 0 0 0 0
A 6760 2 0 0 0 9 19823 0 0 0 6760 0 0 0 0 0 0 0 0 0 0 0
A 6761 2 0 0 0 9 19824 0 0 0 6761 0 0 0 0 0 0 0 0 0 0 0
A 6762 2 0 0 5061 9 19825 0 0 0 6762 0 0 0 0 0 0 0 0 0 0 0
A 6763 2 0 0 3723 9 19826 0 0 0 6763 0 0 0 0 0 0 0 0 0 0 0
A 6764 2 0 0 3722 9 19827 0 0 0 6764 0 0 0 0 0 0 0 0 0 0 0
A 6765 2 0 0 3726 9 19828 0 0 0 6765 0 0 0 0 0 0 0 0 0 0 0
A 6766 2 0 0 3725 9 19829 0 0 0 6766 0 0 0 0 0 0 0 0 0 0 0
A 6767 2 0 0 3729 9 19830 0 0 0 6767 0 0 0 0 0 0 0 0 0 0 0
A 6768 2 0 0 3728 9 19831 0 0 0 6768 0 0 0 0 0 0 0 0 0 0 0
A 6769 2 0 0 3732 9 19832 0 0 0 6769 0 0 0 0 0 0 0 0 0 0 0
A 6770 2 0 0 3731 9 19833 0 0 0 6770 0 0 0 0 0 0 0 0 0 0 0
A 6771 2 0 0 3734 9 19834 0 0 0 6771 0 0 0 0 0 0 0 0 0 0 0
A 6772 2 0 0 5637 9 19835 0 0 0 6772 0 0 0 0 0 0 0 0 0 0 0
A 6773 2 0 0 5062 9 19836 0 0 0 6773 0 0 0 0 0 0 0 0 0 0 0
A 6774 2 0 0 3724 9 19837 0 0 0 6774 0 0 0 0 0 0 0 0 0 0 0
A 6775 2 0 0 3727 9 19838 0 0 0 6775 0 0 0 0 0 0 0 0 0 0 0
A 6776 2 0 0 3730 9 19839 0 0 0 6776 0 0 0 0 0 0 0 0 0 0 0
A 6777 2 0 0 3733 9 19840 0 0 0 6777 0 0 0 0 0 0 0 0 0 0 0
A 6778 2 0 0 5645 9 19841 0 0 0 6778 0 0 0 0 0 0 0 0 0 0 0
A 6779 2 0 0 3739 9 19842 0 0 0 6779 0 0 0 0 0 0 0 0 0 0 0
A 6780 2 0 0 3738 9 19843 0 0 0 6780 0 0 0 0 0 0 0 0 0 0 0
A 6781 2 0 0 3742 9 19844 0 0 0 6781 0 0 0 0 0 0 0 0 0 0 0
A 6782 2 0 0 3741 9 19845 0 0 0 6782 0 0 0 0 0 0 0 0 0 0 0
A 6783 2 0 0 3745 9 19846 0 0 0 6783 0 0 0 0 0 0 0 0 0 0 0
A 6784 2 0 0 5063 9 19847 0 0 0 6784 0 0 0 0 0 0 0 0 0 0 0
A 6785 2 0 0 5064 9 19848 0 0 0 6785 0 0 0 0 0 0 0 0 0 0 0
A 6786 2 0 0 3747 9 19849 0 0 0 6786 0 0 0 0 0 0 0 0 0 0 0
A 6787 2 0 0 3750 9 19850 0 0 0 6787 0 0 0 0 0 0 0 0 0 0 0
A 6788 2 0 0 3735 9 19851 0 0 0 6788 0 0 0 0 0 0 0 0 0 0 0
A 6789 2 0 0 3737 9 19852 0 0 0 6789 0 0 0 0 0 0 0 0 0 0 0
A 6790 2 0 0 3740 9 19853 0 0 0 6790 0 0 0 0 0 0 0 0 0 0 0
A 6791 2 0 0 3743 9 19854 0 0 0 6791 0 0 0 0 0 0 0 0 0 0 0
A 6792 2 0 0 3746 9 19855 0 0 0 6792 0 0 0 0 0 0 0 0 0 0 0
A 6793 2 0 0 3749 9 19856 0 0 0 6793 0 0 0 0 0 0 0 0 0 0 0
A 6794 2 0 0 699 9 19857 0 0 0 6794 0 0 0 0 0 0 0 0 0 0 0
A 6795 2 0 0 5586 9 19858 0 0 0 6795 0 0 0 0 0 0 0 0 0 0 0
A 6796 2 0 0 5065 9 19859 0 0 0 6796 0 0 0 0 0 0 0 0 0 0 0
A 6797 2 0 0 5066 9 19860 0 0 0 6797 0 0 0 0 0 0 0 0 0 0 0
A 6798 2 0 0 0 9 19861 0 0 0 6798 0 0 0 0 0 0 0 0 0 0 0
A 6799 2 0 0 745 9 19862 0 0 0 6799 0 0 0 0 0 0 0 0 0 0 0
A 6800 2 0 0 0 9 19863 0 0 0 6800 0 0 0 0 0 0 0 0 0 0 0
A 6801 2 0 0 3752 9 19864 0 0 0 6801 0 0 0 0 0 0 0 0 0 0 0
A 6802 2 0 0 3755 9 19865 0 0 0 6802 0 0 0 0 0 0 0 0 0 0 0
A 6803 2 0 0 3754 9 19866 0 0 0 6803 0 0 0 0 0 0 0 0 0 0 0
A 6804 2 0 0 3758 9 19867 0 0 0 6804 0 0 0 0 0 0 0 0 0 0 0
A 6805 2 0 0 3757 9 19868 0 0 0 6805 0 0 0 0 0 0 0 0 0 0 0
A 6806 2 0 0 5067 9 19869 0 0 0 6806 0 0 0 0 0 0 0 0 0 0 0
A 6807 2 0 0 5068 9 19870 0 0 0 6807 0 0 0 0 0 0 0 0 0 0 0
A 6808 2 0 0 3764 9 19871 0 0 0 6808 0 0 0 0 0 0 0 0 0 0 0
A 6809 2 0 0 3763 9 19872 0 0 0 6809 0 0 0 0 0 0 0 0 0 0 0
A 6810 2 0 0 3767 9 19873 0 0 0 6810 0 0 0 0 0 0 0 0 0 0 0
A 6811 2 0 0 3766 9 19874 0 0 0 6811 0 0 0 0 0 0 0 0 0 0 0
A 6812 2 0 0 3769 9 19875 0 0 0 6812 0 0 0 0 0 0 0 0 0 0 0
A 6813 2 0 0 3751 9 19876 0 0 0 6813 0 0 0 0 0 0 0 0 0 0 0
A 6814 2 0 0 3753 9 19877 0 0 0 6814 0 0 0 0 0 0 0 0 0 0 0
A 6815 2 0 0 3756 9 19878 0 0 0 6815 0 0 0 0 0 0 0 0 0 0 0
A 6816 2 0 0 5069 9 19879 0 0 0 6816 0 0 0 0 0 0 0 0 0 0 0
A 6817 2 0 0 5070 9 19880 0 0 0 6817 0 0 0 0 0 0 0 0 0 0 0
A 6818 2 0 0 5466 9 19881 0 0 0 6818 0 0 0 0 0 0 0 0 0 0 0
A 6819 2 0 0 3768 9 19882 0 0 0 6819 0 0 0 0 0 0 0 0 0 0 0
A 6820 2 0 0 3771 9 19883 0 0 0 6820 0 0 0 0 0 0 0 0 0 0 0
A 6821 2 0 0 3774 9 19884 0 0 0 6821 0 0 0 0 0 0 0 0 0 0 0
A 6822 2 0 0 3773 9 19885 0 0 0 6822 0 0 0 0 0 0 0 0 0 0 0
A 6823 2 0 0 3777 9 19886 0 0 0 6823 0 0 0 0 0 0 0 0 0 0 0
A 6824 2 0 0 3776 9 19887 0 0 0 6824 0 0 0 0 0 0 0 0 0 0 0
A 6825 2 0 0 3780 9 19888 0 0 0 6825 0 0 0 0 0 0 0 0 0 0 0
A 6826 2 0 0 3779 9 19889 0 0 0 6826 0 0 0 0 0 0 0 0 0 0 0
A 6827 2 0 0 5071 9 19890 0 0 0 6827 0 0 0 0 0 0 0 0 0 0 0
A 6828 2 0 0 5072 9 19891 0 0 0 6828 0 0 0 0 0 0 0 0 0 0 0
A 6829 2 0 0 5073 9 19892 0 0 0 6829 0 0 0 0 0 0 0 0 0 0 0
A 6830 2 0 0 3785 9 19893 0 0 0 6830 0 0 0 0 0 0 0 0 0 0 0
A 6831 2 0 0 3788 9 19894 0 0 0 6831 0 0 0 0 0 0 0 0 0 0 0
A 6832 2 0 0 3770 9 19895 0 0 0 6832 0 0 0 0 0 0 0 0 0 0 0
A 6833 2 0 0 3772 9 19896 0 0 0 6833 0 0 0 0 0 0 0 0 0 0 0
A 6834 2 0 0 3775 9 19897 0 0 0 6834 0 0 0 0 0 0 0 0 0 0 0
A 6835 2 0 0 3778 9 19898 0 0 0 6835 0 0 0 0 0 0 0 0 0 0 0
A 6836 2 0 0 3781 9 19899 0 0 0 6836 0 0 0 0 0 0 0 0 0 0 0
A 6837 2 0 0 3784 9 19900 0 0 0 6837 0 0 0 0 0 0 0 0 0 0 0
A 6838 2 0 0 3787 9 19901 0 0 0 6838 0 0 0 0 0 0 0 0 0 0 0
A 6839 2 0 0 5074 9 19902 0 0 0 6839 0 0 0 0 0 0 0 0 0 0 0
A 6840 2 0 0 5075 9 19903 0 0 0 6840 0 0 0 0 0 0 0 0 0 0 0
A 6841 2 0 0 5076 9 19904 0 0 0 6841 0 0 0 0 0 0 0 0 0 0 0
A 6842 2 0 0 0 9 19905 0 0 0 6842 0 0 0 0 0 0 0 0 0 0 0
A 6843 2 0 0 0 9 19906 0 0 0 6843 0 0 0 0 0 0 0 0 0 0 0
A 6844 2 0 0 0 9 19907 0 0 0 6844 0 0 0 0 0 0 0 0 0 0 0
A 6845 2 0 0 0 9 19908 0 0 0 6845 0 0 0 0 0 0 0 0 0 0 0
A 6846 2 0 0 3790 9 19909 0 0 0 6846 0 0 0 0 0 0 0 0 0 0 0
A 6847 2 0 0 3793 9 19910 0 0 0 6847 0 0 0 0 0 0 0 0 0 0 0
A 6848 2 0 0 3792 9 19911 0 0 0 6848 0 0 0 0 0 0 0 0 0 0 0
A 6849 2 0 0 3796 9 19912 0 0 0 6849 0 0 0 0 0 0 0 0 0 0 0
A 6850 2 0 0 3795 9 19913 0 0 0 6850 0 0 0 0 0 0 0 0 0 0 0
A 6851 2 0 0 5077 9 19914 0 0 0 6851 0 0 0 0 0 0 0 0 0 0 0
A 6852 2 0 0 5078 9 19915 0 0 0 6852 0 0 0 0 0 0 0 0 0 0 0
A 6853 2 0 0 3802 9 19916 0 0 0 6853 0 0 0 0 0 0 0 0 0 0 0
A 6854 2 0 0 3801 9 19917 0 0 0 6854 0 0 0 0 0 0 0 0 0 0 0
A 6855 2 0 0 3805 9 19918 0 0 0 6855 0 0 0 0 0 0 0 0 0 0 0
A 6856 2 0 0 3804 9 19919 0 0 0 6856 0 0 0 0 0 0 0 0 0 0 0
A 6857 2 0 0 3808 9 19920 0 0 0 6857 0 0 0 0 0 0 0 0 0 0 0
A 6858 2 0 0 3807 9 19921 0 0 0 6858 0 0 0 0 0 0 0 0 0 0 0
A 6859 2 0 0 3810 9 19922 0 0 0 6859 0 0 0 0 0 0 0 0 0 0 0
A 6860 2 0 0 3789 9 19923 0 0 0 6860 0 0 0 0 0 0 0 0 0 0 0
A 6861 2 0 0 3791 9 19924 0 0 0 6861 0 0 0 0 0 0 0 0 0 0 0
A 6862 2 0 0 5079 9 19925 0 0 0 6862 0 0 0 0 0 0 0 0 0 0 0
A 6863 2 0 0 5080 9 19926 0 0 0 6863 0 0 0 0 0 0 0 0 0 0 0
A 6864 2 0 0 3800 9 19927 0 0 0 6864 0 0 0 0 0 0 0 0 0 0 0
A 6865 2 0 0 3803 9 19928 0 0 0 6865 0 0 0 0 0 0 0 0 0 0 0
A 6866 2 0 0 3806 9 19929 0 0 0 6866 0 0 0 0 0 0 0 0 0 0 0
A 6867 2 0 0 3809 9 19930 0 0 0 6867 0 0 0 0 0 0 0 0 0 0 0
A 6868 2 0 0 3812 9 19931 0 0 0 6868 0 0 0 0 0 0 0 0 0 0 0
A 6869 2 0 0 3815 9 19932 0 0 0 6869 0 0 0 0 0 0 0 0 0 0 0
A 6870 2 0 0 3814 9 19933 0 0 0 6870 0 0 0 0 0 0 0 0 0 0 0
A 6871 2 0 0 3818 9 19934 0 0 0 6871 0 0 0 0 0 0 0 0 0 0 0
A 6872 2 0 0 3817 9 19935 0 0 0 6872 0 0 0 0 0 0 0 0 0 0 0
A 6873 2 0 0 3821 9 19936 0 0 0 6873 0 0 0 0 0 0 0 0 0 0 0
A 6874 2 0 0 3820 9 19937 0 0 0 6874 0 0 0 0 0 0 0 0 0 0 0
A 6875 2 0 0 3824 9 19938 0 0 0 6875 0 0 0 0 0 0 0 0 0 0 0
A 6876 2 0 0 3823 9 19939 0 0 0 6876 0 0 0 0 0 0 0 0 0 0 0
A 6877 2 0 0 3827 9 19940 0 0 0 6877 0 0 0 0 0 0 0 0 0 0 0
A 6878 2 0 0 3826 9 19941 0 0 0 6878 0 0 0 0 0 0 0 0 0 0 0
A 6879 2 0 0 3830 9 19942 0 0 0 6879 0 0 0 0 0 0 0 0 0 0 0
A 6880 2 0 0 3829 9 19943 0 0 0 6880 0 0 0 0 0 0 0 0 0 0 0
A 6881 2 0 0 3832 9 19944 0 0 0 6881 0 0 0 0 0 0 0 0 0 0 0
A 6882 2 0 0 3811 9 19945 0 0 0 6882 0 0 0 0 0 0 0 0 0 0 0
A 6883 2 0 0 3813 9 19946 0 0 0 6883 0 0 0 0 0 0 0 0 0 0 0
A 6884 2 0 0 3816 9 19947 0 0 0 6884 0 0 0 0 0 0 0 0 0 0 0
A 6885 2 0 0 3819 9 19948 0 0 0 6885 0 0 0 0 0 0 0 0 0 0 0
A 6886 2 0 0 3822 9 19949 0 0 0 6886 0 0 0 0 0 0 0 0 0 0 0
A 6887 2 0 0 3825 9 19950 0 0 0 6887 0 0 0 0 0 0 0 0 0 0 0
A 6888 2 0 0 3828 9 19951 0 0 0 6888 0 0 0 0 0 0 0 0 0 0 0
A 6889 2 0 0 3831 9 19952 0 0 0 6889 0 0 0 0 0 0 0 0 0 0 0
A 6890 2 0 0 0 9 19953 0 0 0 6890 0 0 0 0 0 0 0 0 0 0 0
A 6891 2 0 0 0 9 19954 0 0 0 6891 0 0 0 0 0 0 0 0 0 0 0
A 6892 2 0 0 0 9 19955 0 0 0 6892 0 0 0 0 0 0 0 0 0 0 0
A 6893 2 0 0 0 9 19956 0 0 0 6893 0 0 0 0 0 0 0 0 0 0 0
A 6894 2 0 0 714 9 19957 0 0 0 6894 0 0 0 0 0 0 0 0 0 0 0
A 6895 2 0 0 0 9 19958 0 0 0 6895 0 0 0 0 0 0 0 0 0 0 0
A 6896 2 0 0 0 9 19959 0 0 0 6896 0 0 0 0 0 0 0 0 0 0 0
A 6897 2 0 0 6376 9 19960 0 0 0 6897 0 0 0 0 0 0 0 0 0 0 0
A 6898 2 0 0 3836 9 19961 0 0 0 6898 0 0 0 0 0 0 0 0 0 0 0
A 6899 2 0 0 3833 9 19962 0 0 0 6899 0 0 0 0 0 0 0 0 0 0 0
A 6900 2 0 0 6064 9 19963 0 0 0 6900 0 0 0 0 0 0 0 0 0 0 0
A 6901 2 0 0 3838 9 19964 0 0 0 6901 0 0 0 0 0 0 0 0 0 0 0
A 6902 2 0 0 3840 9 19965 0 0 0 6902 0 0 0 0 0 0 0 0 0 0 0
A 6903 2 0 0 3837 9 19966 0 0 0 6903 0 0 0 0 0 0 0 0 0 0 0
A 6904 2 0 0 3839 9 19967 0 0 0 6904 0 0 0 0 0 0 0 0 0 0 0
A 6905 2 0 0 0 9 19968 0 0 0 6905 0 0 0 0 0 0 0 0 0 0 0
A 6906 2 0 0 0 9 19969 0 0 0 6906 0 0 0 0 0 0 0 0 0 0 0
A 6907 2 0 0 0 9 19970 0 0 0 6907 0 0 0 0 0 0 0 0 0 0 0
A 6908 2 0 0 0 9 19971 0 0 0 6908 0 0 0 0 0 0 0 0 0 0 0
A 6909 2 0 0 0 9 19972 0 0 0 6909 0 0 0 0 0 0 0 0 0 0 0
A 6910 2 0 0 6371 9 19973 0 0 0 6910 0 0 0 0 0 0 0 0 0 0 0
A 6911 2 0 0 0 9 19974 0 0 0 6911 0 0 0 0 0 0 0 0 0 0 0
A 6912 2 0 0 5081 9 19975 0 0 0 6912 0 0 0 0 0 0 0 0 0 0 0
A 6913 2 0 0 3845 9 19976 0 0 0 6913 0 0 0 0 0 0 0 0 0 0 0
A 6914 2 0 0 3844 9 19977 0 0 0 6914 0 0 0 0 0 0 0 0 0 0 0
A 6915 2 0 0 3847 9 19978 0 0 0 6915 0 0 0 0 0 0 0 0 0 0 0
A 6916 2 0 0 6379 9 19979 0 0 0 6916 0 0 0 0 0 0 0 0 0 0 0
A 6917 2 0 0 3843 9 19980 0 0 0 6917 0 0 0 0 0 0 0 0 0 0 0
A 6918 2 0 0 3846 9 19981 0 0 0 6918 0 0 0 0 0 0 0 0 0 0 0
A 6919 2 0 0 3849 9 19982 0 0 0 6919 0 0 0 0 0 0 0 0 0 0 0
A 6920 2 0 0 3852 9 19983 0 0 0 6920 0 0 0 0 0 0 0 0 0 0 0
A 6921 2 0 0 3851 9 19984 0 0 0 6921 0 0 0 0 0 0 0 0 0 0 0
A 6922 2 0 0 3854 9 19985 0 0 0 6922 0 0 0 0 0 0 0 0 0 0 0
A 6923 2 0 0 3848 9 19986 0 0 0 6923 0 0 0 0 0 0 0 0 0 0 0
A 6924 2 0 0 3850 9 19987 0 0 0 6924 0 0 0 0 0 0 0 0 0 0 0
A 6925 2 0 0 5082 9 19988 0 0 0 6925 0 0 0 0 0 0 0 0 0 0 0
A 6926 2 0 0 1980 9 19989 0 0 0 6926 0 0 0 0 0 0 0 0 0 0 0
A 6927 2 0 0 2328 9 19990 0 0 0 6927 0 0 0 0 0 0 0 0 0 0 0
A 6928 2 0 0 1983 9 19991 0 0 0 6928 0 0 0 0 0 0 0 0 0 0 0
A 6929 2 0 0 2331 9 19992 0 0 0 6929 0 0 0 0 0 0 0 0 0 0 0
A 6930 2 0 0 1986 9 19993 0 0 0 6930 0 0 0 0 0 0 0 0 0 0 0
A 6931 2 0 0 2334 9 19994 0 0 0 6931 0 0 0 0 0 0 0 0 0 0 0
A 6932 2 0 0 0 9 19995 0 0 0 6932 0 0 0 0 0 0 0 0 0 0 0
A 6933 2 0 0 3856 9 19996 0 0 0 6933 0 0 0 0 0 0 0 0 0 0 0
A 6934 2 0 0 3859 9 19997 0 0 0 6934 0 0 0 0 0 0 0 0 0 0 0
A 6935 2 0 0 3858 9 19998 0 0 0 6935 0 0 0 0 0 0 0 0 0 0 0
A 6936 2 0 0 3862 9 19999 0 0 0 6936 0 0 0 0 0 0 0 0 0 0 0
A 6937 2 0 0 3861 9 20000 0 0 0 6937 0 0 0 0 0 0 0 0 0 0 0
A 6938 2 0 0 3864 9 20001 0 0 0 6938 0 0 0 0 0 0 0 0 0 0 0
A 6939 2 0 0 5653 9 20002 0 0 0 6939 0 0 0 0 0 0 0 0 0 0 0
A 6940 2 0 0 3857 9 20003 0 0 0 6940 0 0 0 0 0 0 0 0 0 0 0
A 6941 2 0 0 3860 9 20004 0 0 0 6941 0 0 0 0 0 0 0 0 0 0 0
A 6942 2 0 0 5083 9 20005 0 0 0 6942 0 0 0 0 0 0 0 0 0 0 0
A 6943 2 0 0 5084 9 20006 0 0 0 6943 0 0 0 0 0 0 0 0 0 0 0
A 6944 2 0 0 3869 9 20007 0 0 0 6944 0 0 0 0 0 0 0 0 0 0 0
A 6945 2 0 0 5661 9 20008 0 0 0 6945 0 0 0 0 0 0 0 0 0 0 0
A 6946 2 0 0 3872 9 20009 0 0 0 6946 0 0 0 0 0 0 0 0 0 0 0
A 6947 2 0 0 3871 9 20010 0 0 0 6947 0 0 0 0 0 0 0 0 0 0 0
A 6948 2 0 0 3874 9 20011 0 0 0 6948 0 0 0 0 0 0 0 0 0 0 0
A 6949 2 0 0 3865 9 20012 0 0 0 6949 0 0 0 0 0 0 0 0 0 0 0
A 6950 2 0 0 3867 9 20013 0 0 0 6950 0 0 0 0 0 0 0 0 0 0 0
A 6951 2 0 0 5669 9 20014 0 0 0 6951 0 0 0 0 0 0 0 0 0 0 0
A 6952 2 0 0 3873 9 20015 0 0 0 6952 0 0 0 0 0 0 0 0 0 0 0
A 6953 2 0 0 0 9 20016 0 0 0 6953 0 0 0 0 0 0 0 0 0 0 0
A 6954 2 0 0 0 9 20017 0 0 0 6954 0 0 0 0 0 0 0 0 0 0 0
A 6955 2 0 0 0 9 20018 0 0 0 6955 0 0 0 0 0 0 0 0 0 0 0
A 6956 2 0 0 0 9 20019 0 0 0 6956 0 0 0 0 0 0 0 0 0 0 0
A 6957 2 0 0 0 9 20020 0 0 0 6957 0 0 0 0 0 0 0 0 0 0 0
A 6958 2 0 0 0 9 20021 0 0 0 6958 0 0 0 0 0 0 0 0 0 0 0
A 6959 2 0 0 0 9 20022 0 0 0 6959 0 0 0 0 0 0 0 0 0 0 0
A 6960 2 0 0 5085 9 20023 0 0 0 6960 0 0 0 0 0 0 0 0 0 0 0
A 6961 2 0 0 5086 9 20024 0 0 0 6961 0 0 0 0 0 0 0 0 0 0 0
A 6962 2 0 0 3878 9 20025 0 0 0 6962 0 0 0 0 0 0 0 0 0 0 0
A 6963 2 0 0 3882 9 20026 0 0 0 6963 0 0 0 0 0 0 0 0 0 0 0
A 6964 2 0 0 3881 9 20027 0 0 0 6964 0 0 0 0 0 0 0 0 0 0 0
A 6965 2 0 0 3885 9 20028 0 0 0 6965 0 0 0 0 0 0 0 0 0 0 0
A 6966 2 0 0 3884 9 20029 0 0 0 6966 0 0 0 0 0 0 0 0 0 0 0
A 6967 2 0 0 3887 9 20030 0 0 0 6967 0 0 0 0 0 0 0 0 0 0 0
A 6968 2 0 0 6304 9 20031 0 0 0 6968 0 0 0 0 0 0 0 0 0 0 0
A 6969 2 0 0 3877 9 20032 0 0 0 6969 0 0 0 0 0 0 0 0 0 0 0
A 6970 2 0 0 3880 9 20033 0 0 0 6970 0 0 0 0 0 0 0 0 0 0 0
A 6971 2 0 0 6565 9 20034 0 0 0 6971 0 0 0 0 0 0 0 0 0 0 0
A 6972 2 0 0 5793 9 20035 0 0 0 6972 0 0 0 0 0 0 0 0 0 0 0
A 6973 2 0 0 3889 9 20036 0 0 0 6973 0 0 0 0 0 0 0 0 0 0 0
A 6974 2 0 0 5087 9 20037 0 0 0 6974 0 0 0 0 0 0 0 0 0 0 0
A 6975 2 0 0 6168 9 20038 0 0 0 6975 0 0 0 0 0 0 0 0 0 0 0
A 6976 2 0 0 3895 9 20039 0 0 0 6976 0 0 0 0 0 0 0 0 0 0 0
A 6977 2 0 0 3894 9 20040 0 0 0 6977 0 0 0 0 0 0 0 0 0 0 0
A 6978 2 0 0 3898 9 20041 0 0 0 6978 0 0 0 0 0 0 0 0 0 0 0
A 6979 2 0 0 3897 9 20042 0 0 0 6979 0 0 0 0 0 0 0 0 0 0 0
A 6980 2 0 0 3900 9 20043 0 0 0 6980 0 0 0 0 0 0 0 0 0 0 0
A 6981 2 0 0 3888 9 20044 0 0 0 6981 0 0 0 0 0 0 0 0 0 0 0
A 6982 2 0 0 3890 9 20045 0 0 0 6982 0 0 0 0 0 0 0 0 0 0 0
A 6983 2 0 0 3893 9 20046 0 0 0 6983 0 0 0 0 0 0 0 0 0 0 0
A 6984 2 0 0 3896 9 20047 0 0 0 6984 0 0 0 0 0 0 0 0 0 0 0
A 6985 2 0 0 3899 9 20048 0 0 0 6985 0 0 0 0 0 0 0 0 0 0 0
A 6986 2 0 0 0 9 20049 0 0 0 6986 0 0 0 0 0 0 0 0 0 0 0
A 6987 2 0 0 5722 9 20050 0 0 0 6987 0 0 0 0 0 0 0 0 0 0 0
A 6988 2 0 0 0 9 20051 0 0 0 6988 0 0 0 0 0 0 0 0 0 0 0
A 6989 2 0 0 0 9 20052 0 0 0 6989 0 0 0 0 0 0 0 0 0 0 0
A 6990 2 0 0 0 9 20053 0 0 0 6990 0 0 0 0 0 0 0 0 0 0 0
A 6991 2 0 0 0 9 20054 0 0 0 6991 0 0 0 0 0 0 0 0 0 0 0
A 6992 2 0 0 0 9 20055 0 0 0 6992 0 0 0 0 0 0 0 0 0 0 0
A 6993 2 0 0 3902 9 20056 0 0 0 6993 0 0 0 0 0 0 0 0 0 0 0
A 6994 2 0 0 3905 9 20057 0 0 0 6994 0 0 0 0 0 0 0 0 0 0 0
A 6995 2 0 0 3904 9 20058 0 0 0 6995 0 0 0 0 0 0 0 0 0 0 0
A 6996 2 0 0 3908 9 20059 0 0 0 6996 0 0 0 0 0 0 0 0 0 0 0
A 6997 2 0 0 5089 9 20060 0 0 0 6997 0 0 0 0 0 0 0 0 0 0 0
A 6998 2 0 0 3911 9 20061 0 0 0 6998 0 0 0 0 0 0 0 0 0 0 0
A 6999 2 0 0 3910 9 20062 0 0 0 6999 0 0 0 0 0 0 0 0 0 0 0
A 7000 2 0 0 3914 9 20063 0 0 0 7000 0 0 0 0 0 0 0 0 0 0 0
A 7001 2 0 0 3913 9 20064 0 0 0 7001 0 0 0 0 0 0 0 0 0 0 0
A 7002 2 0 0 3916 9 20065 0 0 0 7002 0 0 0 0 0 0 0 0 0 0 0
A 7003 2 0 0 3901 9 20066 0 0 0 7003 0 0 0 0 0 0 0 0 0 0 0
A 7004 2 0 0 3903 9 20067 0 0 0 7004 0 0 0 0 0 0 0 0 0 0 0
A 7005 2 0 0 3906 9 20068 0 0 0 7005 0 0 0 0 0 0 0 0 0 0 0
A 7006 2 0 0 3909 9 20069 0 0 0 7006 0 0 0 0 0 0 0 0 0 0 0
A 7007 2 0 0 5090 9 20070 0 0 0 7007 0 0 0 0 0 0 0 0 0 0 0
A 7008 2 0 0 3915 9 20071 0 0 0 7008 0 0 0 0 0 0 0 0 0 0 0
A 7009 2 0 0 3918 9 20072 0 0 0 7009 0 0 0 0 0 0 0 0 0 0 0
A 7010 2 0 0 3921 9 20073 0 0 0 7010 0 0 0 0 0 0 0 0 0 0 0
A 7011 2 0 0 3920 9 20074 0 0 0 7011 0 0 0 0 0 0 0 0 0 0 0
A 7012 2 0 0 3924 9 20075 0 0 0 7012 0 0 0 0 0 0 0 0 0 0 0
A 7013 2 0 0 3923 9 20076 0 0 0 7013 0 0 0 0 0 0 0 0 0 0 0
A 7014 2 0 0 3927 9 20077 0 0 0 7014 0 0 0 0 0 0 0 0 0 0 0
A 7015 2 0 0 3926 9 20078 0 0 0 7015 0 0 0 0 0 0 0 0 0 0 0
A 7016 2 0 0 3930 9 20079 0 0 0 7016 0 0 0 0 0 0 0 0 0 0 0
A 7017 2 0 0 6307 9 20080 0 0 0 7017 0 0 0 0 0 0 0 0 0 0 0
A 7018 2 0 0 5091 9 20081 0 0 0 7018 0 0 0 0 0 0 0 0 0 0 0
A 7019 2 0 0 3917 9 20082 0 0 0 7019 0 0 0 0 0 0 0 0 0 0 0
A 7020 2 0 0 3919 9 20083 0 0 0 7020 0 0 0 0 0 0 0 0 0 0 0
A 7021 2 0 0 3922 9 20084 0 0 0 7021 0 0 0 0 0 0 0 0 0 0 0
A 7022 2 0 0 3925 9 20085 0 0 0 7022 0 0 0 0 0 0 0 0 0 0 0
A 7023 2 0 0 6315 9 20086 0 0 0 7023 0 0 0 0 0 0 0 0 0 0 0
A 7024 2 0 0 3931 9 20087 0 0 0 7024 0 0 0 0 0 0 0 0 0 0 0
A 7025 2 0 0 0 9 20088 0 0 0 7025 0 0 0 0 0 0 0 0 0 0 0
A 7026 2 0 0 5893 9 20089 0 0 0 7026 0 0 0 0 0 0 0 0 0 0 0
A 7027 2 0 0 0 9 20090 0 0 0 7027 0 0 0 0 0 0 0 0 0 0 0
A 7028 2 0 0 0 9 20091 0 0 0 7028 0 0 0 0 0 0 0 0 0 0 0
A 7029 2 0 0 5092 9 20092 0 0 0 7029 0 0 0 0 0 0 0 0 0 0 0
A 7030 2 0 0 0 9 20093 0 0 0 7030 0 0 0 0 0 0 0 0 0 0 0
A 7031 2 0 0 0 9 20094 0 0 0 7031 0 0 0 0 0 0 0 0 0 0 0
A 7032 2 0 0 3934 9 20095 0 0 0 7032 0 0 0 0 0 0 0 0 0 0 0
A 7033 2 0 0 3937 9 20096 0 0 0 7033 0 0 0 0 0 0 0 0 0 0 0
A 10297 2 0 0 3607 7 19692 0 0 0 10297 0 0 0 0 0 0 0 0 0 0 0
A 11646 1 0 13 0 9234 22246 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
Z
J 133 1 1
V 68 58 7 0
S 0 58 0 0 0
A 0 6 0 0 1 2 0
J 134 1 1
V 71 67 7 0
S 0 67 0 0 0
A 0 6 0 0 1 2 0
J 53 1 1
V 141 97 7 0
S 0 97 0 0 0
A 0 76 0 0 1 68 0
J 21 1 1
V 2055 1493 7 0
S 0 1493 0 0 0
A 0 6 0 0 1 1702 0
J 21 1 1
V 2058 1493 7 0
S 0 1493 0 0 0
A 0 6 0 0 1 1706 0
J 21 1 1
V 2061 1493 7 0
S 0 1493 0 0 0
A 0 6 0 0 1 1710 0
J 21 1 1
V 2064 1493 7 0
S 0 1493 0 0 0
A 0 6 0 0 1 673 0
J 21 1 1
V 2067 1493 7 0
S 0 1493 0 0 0
A 0 6 0 0 1 364 0
J 32 1 1
V 2070 1502 7 0
S 0 1502 0 0 0
A 0 6 0 0 1 3 0
J 32 1 1
V 2073 1502 7 0
S 0 1502 0 0 0
A 0 6 0 0 1 15 0
J 32 1 1
V 2076 1502 7 0
S 0 1502 0 0 0
A 0 6 0 0 1 97 0
J 41 1 1
V 2079 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 3 0
J 41 1 1
V 2082 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 15 0
J 41 1 1
V 2085 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 17 0
J 41 1 1
V 2088 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 102 0
J 41 1 1
V 2091 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 112 0
J 41 1 1
V 2094 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 114 0
J 41 1 1
V 2097 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 116 0
J 41 1 1
V 2100 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 108 0
J 41 1 1
V 2103 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 110 0
J 41 1 1
V 2106 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 120 0
J 41 1 1
V 2109 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 122 0
J 41 1 1
V 2112 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 124 0
J 41 1 1
V 2115 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 126 0
J 41 1 1
V 2118 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 144 0
J 41 1 1
V 2121 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 142 0
J 41 1 1
V 2124 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 438 0
J 41 1 1
V 2127 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 175 0
J 41 1 1
V 2130 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 177 0
J 41 1 1
V 2133 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 442 0
J 41 1 1
V 2136 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 143 0
J 41 1 1
V 2139 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 179 0
J 41 1 1
V 2142 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 148 0
J 41 1 1
V 2145 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 181 0
J 41 1 1
V 2148 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 448 0
J 41 1 1
V 2151 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 450 0
J 41 1 1
V 2154 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 452 0
J 41 1 1
V 2157 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 454 0
J 41 1 1
V 2160 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 147 0
J 41 1 1
V 2163 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 97 0
J 41 1 1
V 2166 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 87 0
J 41 1 1
V 2169 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 78 0
J 41 1 1
V 2172 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 99 0
J 41 1 1
V 2175 1511 7 0
S 0 1511 0 0 0
A 0 6 0 0 1 594 0
J 82 1 1
V 2178 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 2 0
J 82 1 1
V 2181 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 3 0
J 82 1 1
V 2184 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 97 0
J 82 1 1
V 2187 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 99 0
J 82 1 1
V 2190 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 17 0
J 82 1 1
V 2193 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 114 0
J 82 1 1
V 2196 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 118 0
J 82 1 1
V 2199 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 80 0
J 82 1 1
V 2202 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 82 0
J 82 1 1
V 2205 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 89 0
J 82 1 1
V 2208 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 91 0
J 82 1 1
V 2211 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 93 0
J 82 1 1
V 2214 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 95 0
J 82 1 1
V 2217 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 104 0
J 82 1 1
V 2220 1520 7 0
S 0 1520 0 0 0
A 0 6 0 0 1 106 0
J 123 1 1
V 2223 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 15 0
J 123 1 1
V 2226 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 78 0
J 123 1 1
V 2229 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 80 0
J 123 1 1
V 2232 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 82 0
J 123 1 1
V 2235 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 2 0
J 123 1 1
V 2238 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 13 0
J 123 1 1
V 2241 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 3 0
J 123 1 1
V 2244 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 87 0
J 123 1 1
V 2247 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 89 0
J 123 1 1
V 2250 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 91 0
J 123 1 1
V 2253 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 93 0
J 123 1 1
V 2256 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 95 0
J 123 1 1
V 2259 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 97 0
J 123 1 1
V 2262 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 99 0
J 123 1 1
V 2265 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 17 0
J 123 1 1
V 2268 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 102 0
J 123 1 1
V 2271 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 104 0
J 123 1 1
V 2274 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 106 0
J 123 1 1
V 2277 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 108 0
J 123 1 1
V 2280 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 110 0
J 123 1 1
V 2283 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 112 0
J 123 1 1
V 2286 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 114 0
J 123 1 1
V 2289 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 116 0
J 123 1 1
V 2292 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 118 0
J 123 1 1
V 2295 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 120 0
J 123 1 1
V 2298 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 122 0
J 123 1 1
V 2301 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 124 0
J 123 1 1
V 2304 1529 7 0
S 0 1529 0 0 0
A 0 6 0 0 1 126 0
J 157 1 1
V 2307 1538 7 0
S 0 1538 0 0 0
A 0 6 0 0 1 3 0
J 157 1 1
V 2310 1538 7 0
S 0 1538 0 0 0
A 0 6 0 0 1 1960 0
J 157 1 1
V 2313 1538 7 0
S 0 1538 0 0 0
A 0 6 0 0 1 1964 0
J 157 1 1
V 2316 1538 7 0
S 0 1538 0 0 0
A 0 6 0 0 1 1968 0
J 157 1 1
V 2319 1538 7 0
S 0 1538 0 0 0
A 0 6 0 0 1 13 0
J 157 1 1
V 2322 1538 7 0
S 0 1538 0 0 0
A 0 6 0 0 1 89 0
J 157 1 1
V 2325 1538 7 0
S 0 1538 0 0 0
A 0 6 0 0 1 490 0
J 157 1 1
V 2328 1538 7 0
S 0 1538 0 0 0
A 0 6 0 0 1 701 0
J 157 1 1
V 2331 1538 7 0
S 0 1538 0 0 0
A 0 6 0 0 1 597 0
J 157 1 1
V 2334 1538 7 0
S 0 1538 0 0 0
A 0 6 0 0 1 1987 0
J 173 1 1
V 2337 1547 7 0
S 0 1547 0 0 0
A 0 6 0 0 1 2 0
J 173 1 1
V 2340 1547 7 0
S 0 1547 0 0 0
A 0 6 0 0 1 3 0
J 173 1 1
V 2343 1547 7 0
S 0 1547 0 0 0
A 0 6 0 0 1 15 0
J 173 1 1
V 2346 1547 7 0
S 0 1547 0 0 0
A 0 6 0 0 1 97 0
J 173 1 1
V 2349 1547 7 0
S 0 1547 0 0 0
A 0 6 0 0 1 13 0
J 173 1 1
V 2352 1547 7 0
S 0 1547 0 0 0
A 0 6 0 0 1 87 0
J 173 1 1
V 2355 1547 7 0
S 0 1547 0 0 0
A 0 6 0 0 1 78 0
J 193 1 1
V 2358 1556 7 0
S 0 1556 0 0 0
A 0 6 0 0 1 2 0
J 193 1 1
V 2361 1556 7 0
S 0 1556 0 0 0
A 0 6 0 0 1 3 0
J 193 1 1
V 2364 1556 7 0
S 0 1556 0 0 0
A 0 6 0 0 1 15 0
J 193 1 1
V 2367 1556 7 0
S 0 1556 0 0 0
A 0 6 0 0 1 97 0
J 193 1 1
V 2370 1556 7 0
S 0 1556 0 0 0
A 0 6 0 0 1 13 0
J 193 1 1
V 2373 1556 7 0
S 0 1556 0 0 0
A 0 6 0 0 1 87 0
J 211 1 1
V 2376 1565 7 0
S 0 1565 0 0 0
A 0 6 0 0 1 2 0
J 219 1 1
V 2379 1574 7 0
S 0 1574 0 0 0
A 0 6 0 0 1 2 0
J 219 1 1
V 2382 1574 7 0
S 0 1574 0 0 0
A 0 6 0 0 1 3 0
J 227 1 1
V 2385 1583 7 0
S 0 1583 0 0 0
A 0 6 0 0 1 2 0
J 227 1 1
V 2388 1583 7 0
S 0 1583 0 0 0
A 0 6 0 0 1 3 0
J 235 1 1
V 2391 1592 7 0
S 0 1592 0 0 0
A 0 6 0 0 1 2 0
J 235 1 1
V 2394 1592 7 0
S 0 1592 0 0 0
A 0 6 0 0 1 3 0
J 29 1 1
V 4323 4033 7 0
R 0 4036 0 0
A 0 6 0 0 1 3 0
J 75 1 1
V 4329 4039 7 0
R 0 4042 0 0
A 0 6 0 0 1 3 1
A 0 6 0 0 1 15 1
A 0 6 0 0 1 13 1
A 0 6 0 0 1 17 0
J 77 1 1
V 4335 4045 7 0
R 0 4048 0 0
A 0 6 0 0 1 3 1
A 0 6 0 0 1 15 1
A 0 6 0 0 1 13 1
A 0 6 0 0 1 17 0
J 80 1 1
V 4339 4051 7 0
R 0 4054 0 0
A 0 6 0 0 1 13 1
A 0 6 0 0 1 17 0
J 825 1 1
V 11646 9234 7 0
R 0 9234 0 0
A 0 9 0 0 1 6632 1
A 0 9 0 0 1 6633 1
A 0 9 0 0 1 6634 1
A 0 9 0 0 1 6635 1
A 0 9 0 0 1 6636 1
A 0 9 0 0 1 6637 1
A 0 9 0 0 1 6638 1
A 0 9 0 0 1 6639 1
A 0 9 0 0 1 6640 1
A 0 9 0 0 1 6641 1
A 0 9 0 0 1 6642 1
A 0 9 0 0 1 6643 1
A 0 9 0 0 1 6644 1
A 0 9 0 0 1 6645 1
A 0 9 0 0 1 6646 1
A 0 9 0 0 1 6647 1
A 0 9 0 0 1 6647 1
A 0 9 0 0 1 6648 1
A 0 9 0 0 1 6647 1
A 0 9 0 0 1 6649 1
A 0 9 0 0 1 6646 1
A 0 9 0 0 1 6645 1
A 0 9 0 0 1 6650 1
A 0 9 0 0 1 6651 1
A 0 9 0 0 1 6652 1
A 0 9 0 0 1 6653 1
A 0 9 0 0 1 6644 1
A 0 9 0 0 1 6654 1
A 0 9 0 0 1 6655 1
A 0 9 0 0 1 6656 1
A 0 9 0 0 1 6657 1
A 0 9 0 0 1 6658 1
A 0 9 0 0 1 6659 1
A 0 9 0 0 1 6660 1
A 0 9 0 0 1 6661 1
A 0 9 0 0 1 6662 1
A 0 9 0 0 1 6663 1
A 0 9 0 0 1 6664 1
A 0 9 0 0 1 6665 1
A 0 9 0 0 1 6666 1
A 0 9 0 0 1 6667 1
A 0 9 0 0 1 6641 1
A 0 9 0 0 1 6668 1
A 0 9 0 0 1 6669 1
A 0 9 0 0 1 6670 1
A 0 9 0 0 1 6671 1
A 0 9 0 0 1 6672 1
A 0 9 0 0 1 6673 1
A 0 9 0 0 1 6674 1
A 0 9 0 0 1 6675 1
A 0 9 0 0 1 6676 1
A 0 9 0 0 1 6677 1
A 0 9 0 0 1 6678 1
A 0 9 0 0 1 6679 1
A 0 9 0 0 1 6680 1
A 0 9 0 0 1 6681 1
A 0 9 0 0 1 6682 1
A 0 9 0 0 1 6683 1
A 0 9 0 0 1 6662 1
A 0 9 0 0 1 6684 1
A 0 9 0 0 1 6685 1
A 0 9 0 0 1 6686 1
A 0 9 0 0 1 6687 1
A 0 9 0 0 1 6688 1
A 0 9 0 0 1 6689 1
A 0 9 0 0 1 6690 1
A 0 9 0 0 1 6691 1
A 0 9 0 0 1 6692 1
A 0 9 0 0 1 6686 1
A 0 9 0 0 1 6693 1
A 0 9 0 0 1 6694 1
A 0 9 0 0 1 6695 1
A 0 9 0 0 1 6646 1
A 0 9 0 0 1 6696 1
A 0 9 0 0 1 6697 1
A 0 9 0 0 1 6698 1
A 0 9 0 0 1 6699 1
A 0 9 0 0 1 6700 1
A 0 9 0 0 1 6701 1
A 0 9 0 0 1 6702 1
A 0 9 0 0 1 6703 1
A 0 9 0 0 1 6642 1
A 0 9 0 0 1 6704 1
A 0 9 0 0 1 6705 1
A 0 9 0 0 1 6706 1
A 0 9 0 0 1 6707 1
A 0 9 0 0 1 6708 1
A 0 9 0 0 1 6671 1
A 0 9 0 0 1 6709 1
A 0 9 0 0 1 6710 1
A 0 9 0 0 1 6711 1
A 0 9 0 0 1 6712 1
A 0 9 0 0 1 6713 1
A 0 9 0 0 1 6714 1
A 0 9 0 0 1 6715 1
A 0 9 0 0 1 6716 1
A 0 9 0 0 1 6717 1
A 0 9 0 0 1 6718 1
A 0 9 0 0 1 6719 1
A 0 9 0 0 1 6720 1
A 0 9 0 0 1 6721 1
A 0 9 0 0 1 6722 1
A 0 9 0 0 1 6723 1
A 0 9 0 0 1 6724 1
A 0 9 0 0 1 6725 1
A 0 9 0 0 1 6726 1
A 0 9 0 0 1 6671 1
A 0 9 0 0 1 6704 1
A 0 9 0 0 1 6727 1
A 0 9 0 0 1 6728 1
A 0 9 0 0 1 6686 1
A 0 9 0 0 1 6729 1
A 0 9 0 0 1 6730 1
A 0 9 0 0 1 6731 1
A 0 9 0 0 1 6729 1
A 0 9 0 0 1 6732 1
A 0 9 0 0 1 6690 1
A 0 9 0 0 1 6733 1
A 0 9 0 0 1 6734 1
A 0 9 0 0 1 6735 1
A 0 9 0 0 1 6736 1
A 0 9 0 0 1 6737 1
A 0 9 0 0 1 6738 1
A 0 9 0 0 1 6654 1
A 0 9 0 0 1 6656 1
A 0 9 0 0 1 6643 1
A 0 9 0 0 1 6702 1
A 0 9 0 0 1 6662 1
A 0 9 0 0 1 6664 1
A 0 9 0 0 1 6739 1
A 0 9 0 0 1 6706 1
A 0 9 0 0 1 6740 1
A 0 9 0 0 1 6741 1
A 0 9 0 0 1 6672 1
A 0 9 0 0 1 6710 1
A 0 9 0 0 1 6742 1
A 0 9 0 0 1 6743 1
A 0 9 0 0 1 6744 1
A 0 9 0 0 1 6715 1
A 0 9 0 0 1 6745 1
A 0 9 0 0 1 6746 1
A 0 9 0 0 1 6747 1
A 0 9 0 0 1 6748 1
A 0 9 0 0 1 6749 1
A 0 9 0 0 1 6750 1
A 0 9 0 0 1 6751 1
A 0 9 0 0 1 6752 1
A 0 9 0 0 1 6753 1
A 0 9 0 0 1 6754 1
A 0 9 0 0 1 6755 1
A 0 9 0 0 1 6756 1
A 0 9 0 0 1 6757 1
A 0 9 0 0 1 6758 1
A 0 9 0 0 1 6759 1
A 0 9 0 0 1 6760 1
A 0 9 0 0 1 6726 1
A 0 9 0 0 1 6761 1
A 0 9 0 0 1 6762 1
A 0 9 0 0 1 6763 1
A 0 9 0 0 1 6647 1
A 0 9 0 0 1 6764 1
A 0 9 0 0 1 6765 1
A 0 9 0 0 1 6766 1
A 0 9 0 0 1 6767 1
A 0 9 0 0 1 6729 1
A 0 9 0 0 1 6768 1
A 0 9 0 0 1 6764 1
A 0 9 0 0 1 6734 1
A 0 9 0 0 1 6694 1
A 0 9 0 0 1 6647 1
A 0 9 0 0 1 6769 1
A 0 9 0 0 1 6770 1
A 0 9 0 0 1 6656 1
A 0 9 0 0 1 6701 1
A 0 9 0 0 1 6661 1
A 0 9 0 0 1 6642 1
A 0 9 0 0 1 6771 1
A 0 9 0 0 1 6706 1
A 0 9 0 0 1 6772 1
A 0 9 0 0 1 6773 1
A 0 9 0 0 1 6673 1
A 0 9 0 0 1 6675 1
A 0 9 0 0 1 6774 1
A 0 9 0 0 1 6744 1
A 0 9 0 0 1 6775 1
A 0 9 0 0 1 6776 1
A 0 9 0 0 1 6718 1
A 0 9 0 0 1 6777 1
A 0 9 0 0 1 6778 1
A 0 9 0 0 1 6750 1
A 0 9 0 0 1 6779 1
A 0 9 0 0 1 6780 1
A 0 9 0 0 1 6781 1
A 0 9 0 0 1 6636 1
A 0 9 0 0 1 6679 1
A 0 9 0 0 1 6782 1
A 0 9 0 0 1 6783 1
A 0 9 0 0 1 6784 1
A 0 9 0 0 1 6635 1
A 0 9 0 0 1 6785 1
A 0 9 0 0 1 6786 1
A 0 9 0 0 1 6787 1
A 0 9 0 0 1 6788 1
A 0 9 0 0 1 6789 1
A 0 9 0 0 1 6790 1
A 0 9 0 0 1 6715 1
A 0 9 0 0 1 6672 1
A 0 9 0 0 1 6791 1
A 0 9 0 0 1 6700 1
A 0 9 0 0 1 6646 1
A 0 9 0 0 1 6792 1
A 0 9 0 0 1 6765 1
A 0 9 0 0 1 6766 1
A 0 9 0 0 1 6731 1
A 0 9 0 0 1 6732 1
A 0 9 0 0 1 6793 1
A 0 9 0 0 1 6734 1
A 0 9 0 0 1 6794 1
A 0 9 0 0 1 6685 1
A 0 9 0 0 1 6697 1
A 0 9 0 0 1 6699 1
A 0 9 0 0 1 6643 1
A 0 9 0 0 1 6795 1
A 0 9 0 0 1 6796 1
A 0 9 0 0 1 6666 1
A 0 9 0 0 1 6797 1
A 0 9 0 0 1 6798 1
A 0 9 0 0 1 6640 1
A 0 9 0 0 1 6799 1
A 0 9 0 0 1 6774 1
A 0 9 0 0 1 6744 1
A 0 9 0 0 1 6800 1
A 0 9 0 0 1 6801 1
A 0 9 0 0 1 6802 1
A 0 9 0 0 1 6803 1
A 0 9 0 0 1 6790 1
A 0 9 0 0 1 6779 1
A 0 9 0 0 1 6804 1
A 0 9 0 0 1 6805 1
A 0 9 0 0 1 6806 1
A 0 9 0 0 1 6807 1
A 0 9 0 0 1 6808 1
A 0 9 0 0 1 6809 1
A 0 9 0 0 1 6810 1
A 0 9 0 0 1 6811 1
A 0 9 0 0 1 6812 1
A 0 9 0 0 1 6813 1
A 0 9 0 0 1 6814 1
A 0 9 0 0 1 6815 1
A 0 9 0 0 1 6816 1
A 0 9 0 0 1 6817 1
A 0 9 0 0 1 6818 1
A 0 9 0 0 1 6819 1
A 0 9 0 0 1 6784 1
A 0 9 0 0 1 6752 1
A 0 9 0 0 1 6638 1
A 0 9 0 0 1 6675 1
A 0 9 0 0 1 6706 1
A 0 9 0 0 1 6820 1
A 0 9 0 0 1 6821 1
A 0 9 0 0 1 6686 1
A 0 9 0 0 1 6822 1
A 0 9 0 0 1 6765 1
A 0 9 0 0 1 6823 1
A 0 9 0 0 1 6690 1
A 0 9 0 0 1 6686 1
A 0 9 0 0 1 6824 1
A 0 9 0 0 1 6737 1
A 0 9 0 0 1 6644 1
A 0 9 0 0 1 6825 1
A 0 9 0 0 1 6820 1
A 0 9 0 0 1 6826 1
A 0 9 0 0 1 6771 1
A 0 9 0 0 1 6797 1
A 0 9 0 0 1 6670 1
A 0 9 0 0 1 6827 1
A 0 9 0 0 1 6828 1
A 0 9 0 0 1 6829 1
A 0 9 0 0 1 6830 1
A 0 9 0 0 1 6776 1
A 0 9 0 0 1 6831 1
A 0 9 0 0 1 6725 1
A 0 9 0 0 1 6790 1
A 0 9 0 0 1 6832 1
A 0 9 0 0 1 6833 1
A 0 9 0 0 1 6834 1
A 0 9 0 0 1 6835 1
A 0 9 0 0 1 6836 1
A 0 9 0 0 1 6837 1
A 0 9 0 0 1 6838 1
A 0 9 0 0 1 6839 1
A 0 9 0 0 1 6840 1
A 0 9 0 0 1 6841 1
A 0 9 0 0 1 6842 1
A 0 9 0 0 1 6843 1
A 0 9 0 0 1 6844 1
A 0 9 0 0 1 6845 1
A 0 9 0 0 1 6846 1
A 0 9 0 0 1 6847 1
A 0 9 0 0 1 6848 1
A 0 9 0 0 1 6849 1
A 0 9 0 0 1 6850 1
A 0 9 0 0 1 6851 1
A 0 9 0 0 1 6852 1
A 0 9 0 0 1 6724 1
A 0 9 0 0 1 6725 1
A 0 9 0 0 1 6853 1
A 0 9 0 0 1 6741 1
A 0 9 0 0 1 6796 1
A 0 9 0 0 1 6699 1
A 0 9 0 0 1 6854 1
A 0 9 0 0 1 6768 1
A 0 9 0 0 1 6822 1
A 0 9 0 0 1 6689 1
A 0 9 0 0 1 6855 1
A 0 9 0 0 1 6824 1
A 0 9 0 0 1 6650 1
A 0 9 0 0 1 6698 1
A 0 9 0 0 1 6856 1
A 0 9 0 0 1 6795 1
A 0 9 0 0 1 6664 1
A 0 9 0 0 1 6667 1
A 0 9 0 0 1 6857 1
A 0 9 0 0 1 6640 1
A 0 9 0 0 1 6675 1
A 0 9 0 0 1 6829 1
A 0 9 0 0 1 6715 1
A 0 9 0 0 1 6717 1
A 0 9 0 0 1 6719 1
A 0 9 0 0 1 6749 1
A 0 9 0 0 1 6858 1
A 0 9 0 0 1 6859 1
A 0 9 0 0 1 6754 1
A 0 9 0 0 1 6860 1
A 0 9 0 0 1 6836 1
A 0 9 0 0 1 6861 1
A 0 9 0 0 1 6862 1
A 0 9 0 0 1 6863 1
A 0 9 0 0 1 6758 1
A 0 9 0 0 1 6864 1
A 0 9 0 0 1 6865 1
A 0 9 0 0 1 6819 1
A 0 9 0 0 1 6866 1
A 0 9 0 0 1 6846 1
A 0 9 0 0 1 6867 1
A 0 9 0 0 1 6868 1
A 0 9 0 0 1 6869 1
A 0 9 0 0 1 6870 1
A 0 9 0 0 1 6871 1
A 0 9 0 0 1 6872 1
A 0 9 0 0 1 6873 1
A 0 9 0 0 1 6874 1
A 0 9 0 0 1 6875 1
A 0 9 0 0 1 6876 1
A 0 9 0 0 1 6877 1
A 0 9 0 0 1 6878 1
A 0 9 0 0 1 6801 1
A 0 9 0 0 1 6675 1
A 0 9 0 0 1 6641 1
A 0 9 0 0 1 6660 1
A 0 9 0 0 1 6652 1
A 0 9 0 0 1 6686 1
A 0 9 0 0 1 6732 1
A 0 9 0 0 1 6692 1
A 0 9 0 0 1 6694 1
A 0 9 0 0 1 6737 1
A 0 9 0 0 1 6654 1
A 0 9 0 0 1 6658 1
A 0 9 0 0 1 6879 1
A 0 9 0 0 1 6665 1
A 0 9 0 0 1 6797 1
A 0 9 0 0 1 6761 1
A 0 9 0 0 1 6710 1
A 0 9 0 0 1 6774 1
A 0 9 0 0 1 6880 1
A 0 9 0 0 1 6881 1
A 0 9 0 0 1 6719 1
A 0 9 0 0 1 6882 1
A 0 9 0 0 1 6751 1
A 0 9 0 0 1 6883 1
A 0 9 0 0 1 6884 1
A 0 9 0 0 1 6807 1
A 0 9 0 0 1 6885 1
A 0 9 0 0 1 6886 1
A 0 9 0 0 1 6839 1
A 0 9 0 0 1 6887 1
A 0 9 0 0 1 6888 1
A 0 9 0 0 1 6889 1
A 0 9 0 0 1 6844 1
A 0 9 0 0 1 6890 1
A 0 9 0 0 1 6891 1
A 0 9 0 0 1 6892 1
A 0 9 0 0 1 6893 1
A 0 9 0 0 1 6894 1
A 0 9 0 0 1 6895 1
A 0 9 0 0 1 6896 1
A 0 9 0 0 1 6897 1
A 0 9 0 0 1 6898 1
A 0 9 0 0 1 6899 1
A 0 9 0 0 1 6900 1
A 0 9 0 0 1 6901 1
A 0 9 0 0 1 6902 1
A 0 9 0 0 1 6872 1
A 0 9 0 0 1 6903 1
A 0 9 0 0 1 6852 1
A 0 9 0 0 1 6904 1
A 0 9 0 0 1 6905 1
A 0 9 0 0 1 6715 1
A 0 9 0 0 1 6709 1
A 0 9 0 0 1 6906 1
A 0 9 0 0 1 6727 1
A 0 9 0 0 1 6685 1
A 0 9 0 0 1 6764 1
A 0 9 0 0 1 6907 1
A 0 9 0 0 1 6685 1
A 0 9 0 0 1 6770 1
A 0 9 0 0 1 6658 1
A 0 9 0 0 1 6703 1
A 0 9 0 0 1 6906 1
A 0 9 0 0 1 6707 1
A 0 9 0 0 1 6908 1
A 0 9 0 0 1 6828 1
A 0 9 0 0 1 6853 1
A 0 9 0 0 1 6909 1
A 0 9 0 0 1 6910 1
A 0 9 0 0 1 6911 1
A 0 9 0 0 1 6858 1
A 0 9 0 0 1 6912 1
A 0 9 0 0 1 6636 1
A 0 9 0 0 1 6913 1
A 0 9 0 0 1 6914 1
A 0 9 0 0 1 6862 1
A 0 9 0 0 1 6852 1
A 0 9 0 0 1 6915 1
A 0 9 0 0 1 6916 1
A 0 9 0 0 1 6917 1
A 0 9 0 0 1 6866 1
A 0 9 0 0 1 6918 1
A 0 9 0 0 1 6722 1
A 0 9 0 0 1 6893 1
A 0 9 0 0 1 6919 1
A 0 9 0 0 1 6871 1
A 0 9 0 0 1 6920 1
A 0 9 0 0 1 6921 1
A 0 9 0 0 1 6922 1
A 0 9 0 0 1 6923 1
A 0 9 0 0 1 6924 1
A 0 9 0 0 1 6925 1
A 0 9 0 0 1 6926 1
A 0 9 0 0 1 6927 1
A 0 9 0 0 1 6928 1
A 0 9 0 0 1 6929 1
A 0 9 0 0 1 6923 1
A 0 9 0 0 1 6930 1
A 0 9 0 0 1 6931 1
A 0 9 0 0 1 6932 1
A 0 9 0 0 1 6781 1
A 0 9 0 0 1 6933 1
A 0 9 0 0 1 6726 1
A 0 9 0 0 1 6773 1
A 0 9 0 0 1 6934 1
A 0 9 0 0 1 6763 1
A 0 9 0 0 1 6935 1
A 0 9 0 0 1 6935 1
A 0 9 0 0 1 6936 1
A 0 9 0 0 1 6856 1
A 0 9 0 0 1 6879 1
A 0 9 0 0 1 6739 1
A 0 9 0 0 1 6740 1
A 0 9 0 0 1 6709 1
A 0 9 0 0 1 6937 1
A 0 9 0 0 1 6938 1
A 0 9 0 0 1 6717 1
A 0 9 0 0 1 6777 1
A 0 9 0 0 1 6790 1
A 0 9 0 0 1 6752 1
A 0 9 0 0 1 6939 1
A 0 9 0 0 1 6940 1
A 0 9 0 0 1 6877 1
A 0 9 0 0 1 6862 1
A 0 9 0 0 1 6941 1
A 0 9 0 0 1 6942 1
A 0 9 0 0 1 6815 1
A 0 9 0 0 1 6844 1
A 0 9 0 0 1 6943 1
A 0 9 0 0 1 6944 1
A 0 9 0 0 1 6945 1
A 0 9 0 0 1 6946 1
A 0 9 0 0 1 6947 1
A 0 9 0 0 1 6818 1
A 0 9 0 0 1 6948 1
A 0 9 0 0 1 6922 1
A 0 9 0 0 1 6949 1
A 0 9 0 0 1 6950 1
A 0 9 0 0 1 6951 1
A 0 9 0 0 1 6952 1
A 0 9 0 0 1 6953 1
A 0 9 0 0 1 6954 1
A 0 9 0 0 1 6955 1
A 0 9 0 0 1 6956 1
A 0 9 0 0 1 6928 1
A 0 9 0 0 1 6957 1
A 0 9 0 0 1 6958 1
A 0 9 0 0 1 6959 1
A 0 9 0 0 1 6960 1
A 0 9 0 0 1 6961 1
A 0 9 0 0 1 6914 1
A 0 9 0 0 1 6912 1
A 0 9 0 0 1 6719 1
A 0 9 0 0 1 6713 1
A 0 9 0 0 1 6741 1
A 0 9 0 0 1 6762 1
A 0 9 0 0 1 6684 1
A 0 9 0 0 1 6821 1
A 0 9 0 0 1 6763 1
A 0 9 0 0 1 6661 1
A 0 9 0 0 1 6771 1
A 0 9 0 0 1 6740 1
A 0 9 0 0 1 6827 1
A 0 9 0 0 1 6962 1
A 0 9 0 0 1 6830 1
A 0 9 0 0 1 6963 1
A 0 9 0 0 1 6803 1
A 0 9 0 0 1 6858 1
A 0 9 0 0 1 6964 1
A 0 9 0 0 1 6759 1
A 0 9 0 0 1 6965 1
A 0 9 0 0 1 6932 1
A 0 9 0 0 1 6863 1
A 0 9 0 0 1 6915 1
A 0 9 0 0 1 6966 1
A 0 9 0 0 1 6844 1
A 0 9 0 0 1 6967 1
A 0 9 0 0 1 6867 1
A 0 9 0 0 1 6968 1
A 0 9 0 0 1 6919 1
A 0 9 0 0 1 6969 1
A 0 9 0 0 1 6970 1
A 0 9 0 0 1 6971 1
A 0 9 0 0 1 6972 1
A 0 9 0 0 1 6973 1
A 0 9 0 0 1 6974 1
A 0 9 0 0 1 6926 1
A 0 9 0 0 1 6975 1
A 0 9 0 0 1 6976 1
A 0 9 0 0 1 6977 1
A 0 9 0 0 1 6978 1
A 0 9 0 0 1 6979 1
A 0 9 0 0 1 6956 1
A 0 9 0 0 1 6980 1
A 0 9 0 0 1 6928 1
A 0 9 0 0 1 6957 1
A 0 9 0 0 1 6958 1
A 0 9 0 0 1 6981 1
A 0 9 0 0 1 6982 1
A 0 9 0 0 1 6983 1
A 0 9 0 0 1 6915 1
A 0 9 0 0 1 6783 1
A 0 9 0 0 1 6804 1
A 0 9 0 0 1 6984 1
A 0 9 0 0 1 6985 1
A 0 9 0 0 1 6773 1
A 0 9 0 0 1 6986 1
A 0 9 0 0 1 6825 1
A 0 9 0 0 1 6820 1
A 0 9 0 0 1 6986 1
A 0 9 0 0 1 6707 1
A 0 9 0 0 1 6709 1
A 0 9 0 0 1 6962 1
A 0 9 0 0 1 6715 1
A 0 9 0 0 1 6718 1
A 0 9 0 0 1 6778 1
A 0 9 0 0 1 6832 1
A 0 9 0 0 1 6987 1
A 0 9 0 0 1 6988 1
A 0 9 0 0 1 6837 1
A 0 9 0 0 1 6989 1
A 0 9 0 0 1 6678 1
A 0 9 0 0 1 6842 1
A 0 9 0 0 1 6990 1
A 0 9 0 0 1 6991 1
A 0 9 0 0 1 6992 1
A 0 9 0 0 1 6993 1
A 0 9 0 0 1 6787 1
A 0 9 0 0 1 6994 1
A 0 9 0 0 1 6995 1
A 0 9 0 0 1 6996 1
A 0 9 0 0 1 6922 1
A 0 9 0 0 1 6997 1
A 0 9 0 0 1 6998 1
A 0 9 0 0 1 6999 1
A 0 9 0 0 1 6951 1
A 0 9 0 0 1 6926 1
A 0 9 0 0 1 6975 1
A 0 9 0 0 1 6976 1
A 0 9 0 0 1 6977 1
A 0 9 0 0 1 6978 1
A 0 9 0 0 1 6979 1
A 0 9 0 0 1 6956 1
A 0 9 0 0 1 6980 1
A 0 9 0 0 1 6928 1
A 0 9 0 0 1 6957 1
A 0 9 0 0 1 6958 1
A 0 9 0 0 1 6981 1
A 0 9 0 0 1 7000 1
A 0 9 0 0 1 6945 1
A 0 9 0 0 1 6943 1
A 0 9 0 0 1 7001 1
A 0 9 0 0 1 6914 1
A 0 9 0 0 1 7002 1
A 0 9 0 0 1 6720 1
A 0 9 0 0 1 6880 1
A 0 9 0 0 1 6709 1
A 0 9 0 0 1 6666 1
A 0 9 0 0 1 6642 1
A 0 9 0 0 1 7003 1
A 0 9 0 0 1 6908 1
A 0 9 0 0 1 6937 1
A 0 9 0 0 1 7004 1
A 0 9 0 0 1 6718 1
A 0 9 0 0 1 7005 1
A 0 9 0 0 1 7006 1
A 0 9 0 0 1 7007 1
A 0 9 0 0 1 6782 1
A 0 9 0 0 1 7008 1
A 0 9 0 0 1 6863 1
A 0 9 0 0 1 6942 1
A 0 9 0 0 1 7009 1
A 0 9 0 0 1 7010 1
A 0 9 0 0 1 7011 1
A 0 9 0 0 1 7012 1
A 0 9 0 0 1 6757 1
A 0 9 0 0 1 6946 1
A 0 9 0 0 1 7013 1
A 0 9 0 0 1 7014 1
A 0 9 0 0 1 6995 1
A 0 9 0 0 1 6996 1
A 0 9 0 0 1 6922 1
A 0 9 0 0 1 6997 1
A 0 9 0 0 1 6998 1
A 0 9 0 0 1 6999 1
A 0 9 0 0 1 6951 1
A 0 9 0 0 1 6926 1
A 0 9 0 0 1 6975 1
A 0 9 0 0 1 6976 1
A 0 9 0 0 1 6977 1
A 0 9 0 0 1 6978 1
A 0 9 0 0 1 6979 1
A 0 9 0 0 1 6956 1
A 0 9 0 0 1 6980 1
A 0 9 0 0 1 6928 1
A 0 9 0 0 1 6957 1
A 0 9 0 0 1 6958 1
A 0 9 0 0 1 6981 1
A 0 9 0 0 1 7000 1
A 0 9 0 0 1 6945 1
A 0 9 0 0 1 6943 1
A 0 9 0 0 1 7009 1
A 0 9 0 0 1 7015 1
A 0 9 0 0 1 6886 1
A 0 9 0 0 1 6636 1
A 0 9 0 0 1 6790 1
A 0 9 0 0 1 7016 1
A 0 9 0 0 1 6828 1
A 0 9 0 0 1 6668 1
A 0 9 0 0 1 6761 1
A 0 9 0 0 1 6711 1
A 0 9 0 0 1 6880 1
A 0 9 0 0 1 7017 1
A 0 9 0 0 1 6882 1
A 0 9 0 0 1 6752 1
A 0 9 0 0 1 6636 1
A 0 9 0 0 1 7018 1
A 0 9 0 0 1 6838 1
A 0 9 0 0 1 6812 1
A 0 9 0 0 1 6942 1
A 0 9 0 0 1 7019 1
A 0 9 0 0 1 7020 1
A 0 9 0 0 1 6866 1
A 0 9 0 0 1 7011 1
A 0 9 0 0 1 7012 1
A 0 9 0 0 1 6757 1
A 0 9 0 0 1 6946 1
A 0 9 0 0 1 7013 1
A 0 9 0 0 1 7014 1
A 0 9 0 0 1 6995 1
A 0 9 0 0 1 6996 1
A 0 9 0 0 1 6922 1
A 0 9 0 0 1 6997 1
A 0 9 0 0 1 6998 1
A 0 9 0 0 1 6999 1
A 0 9 0 0 1 6951 1
A 0 9 0 0 1 6926 1
A 0 9 0 0 1 6975 1
A 0 9 0 0 1 6976 1
A 0 9 0 0 1 6977 1
A 0 9 0 0 1 6978 1
A 0 9 0 0 1 6979 1
A 0 9 0 0 1 6956 1
A 0 9 0 0 1 6980 1
A 0 9 0 0 1 6928 1
A 0 9 0 0 1 6957 1
A 0 9 0 0 1 6958 1
A 0 9 0 0 1 6981 1
A 0 9 0 0 1 7000 1
A 0 9 0 0 1 6945 1
A 0 9 0 0 1 6943 1
A 0 9 0 0 1 7009 1
A 0 9 0 0 1 7015 1
A 0 9 0 0 1 6989 1
A 0 9 0 0 1 6914 1
A 0 9 0 0 1 7021 1
A 0 9 0 0 1 7022 1
A 0 9 0 0 1 7023 1
A 0 9 0 0 1 7024 1
A 0 9 0 0 1 6674 1
A 0 9 0 0 1 6744 1
A 0 9 0 0 1 6746 1
A 0 9 0 0 1 7025 1
A 0 9 0 0 1 7026 1
A 0 9 0 0 1 6724 1
A 0 9 0 0 1 6789 1
A 0 9 0 0 1 6861 1
A 0 9 0 0 1 7027 1
A 0 9 0 0 1 7028 1
A 0 9 0 0 1 6942 1
A 0 9 0 0 1 7019 1
A 0 9 0 0 1 7020 1
A 0 9 0 0 1 6866 1
A 0 9 0 0 1 7011 1
A 0 9 0 0 1 7012 1
A 0 9 0 0 1 6757 1
A 0 9 0 0 1 6946 1
A 0 9 0 0 1 7013 1
A 0 9 0 0 1 7014 1
A 0 9 0 0 1 6995 1
A 0 9 0 0 1 6996 1
A 0 9 0 0 1 6922 1
A 0 9 0 0 1 6997 1
A 0 9 0 0 1 6998 1
A 0 9 0 0 1 6999 1
A 0 9 0 0 1 6951 1
A 0 9 0 0 1 6926 1
A 0 9 0 0 1 6975 1
A 0 9 0 0 1 6976 1
A 0 9 0 0 1 6977 1
A 0 9 0 0 1 6978 1
A 0 9 0 0 1 6979 1
A 0 9 0 0 1 6956 1
A 0 9 0 0 1 6980 1
A 0 9 0 0 1 6928 1
A 0 9 0 0 1 6957 1
A 0 9 0 0 1 6958 1
A 0 9 0 0 1 6981 1
A 0 9 0 0 1 7000 1
A 0 9 0 0 1 6945 1
A 0 9 0 0 1 6943 1
A 0 9 0 0 1 7009 1
A 0 9 0 0 1 7015 1
A 0 9 0 0 1 6989 1
A 0 9 0 0 1 6914 1
A 0 9 0 0 1 7021 1
A 0 9 0 0 1 6805 1
A 0 9 0 0 1 7029 1
A 0 9 0 0 1 7030 1
A 0 9 0 0 1 6718 1
A 0 9 0 0 1 7016 1
A 0 9 0 0 1 7031 1
A 0 9 0 0 1 7032 1
A 0 9 0 0 1 6883 1
A 0 9 0 0 1 6724 1
A 0 9 0 0 1 6789 1
A 0 9 0 0 1 6861 1
A 0 9 0 0 1 7027 1
A 0 9 0 0 1 7028 1
A 0 9 0 0 1 6942 1
A 0 9 0 0 1 7019 1
A 0 9 0 0 1 7020 1
A 0 9 0 0 1 6866 1
A 0 9 0 0 1 7011 1
A 0 9 0 0 1 7012 1
A 0 9 0 0 1 6757 1
A 0 9 0 0 1 6946 1
A 0 9 0 0 1 7013 1
A 0 9 0 0 1 7014 1
A 0 9 0 0 1 6995 1
A 0 9 0 0 1 6996 1
A 0 9 0 0 1 6922 1
A 0 9 0 0 1 6997 1
A 0 9 0 0 1 6998 1
A 0 9 0 0 1 6999 1
A 0 9 0 0 1 6951 1
A 0 9 0 0 1 6926 1
A 0 9 0 0 1 6975 1
A 0 9 0 0 1 6976 1
A 0 9 0 0 1 6977 1
A 0 9 0 0 1 6978 1
A 0 9 0 0 1 6979 1
A 0 9 0 0 1 6956 1
A 0 9 0 0 1 6980 1
A 0 9 0 0 1 6928 1
A 0 9 0 0 1 6957 1
A 0 9 0 0 1 6958 1
A 0 9 0 0 1 6981 1
A 0 9 0 0 1 7000 1
A 0 9 0 0 1 6945 1
A 0 9 0 0 1 6943 1
A 0 9 0 0 1 7009 1
A 0 9 0 0 1 7015 1
A 0 9 0 0 1 6989 1
A 0 9 0 0 1 6914 1
A 0 9 0 0 1 7021 1
A 0 9 0 0 1 6805 1
A 0 9 0 0 1 7029 1
A 0 9 0 0 1 7030 1
A 0 9 0 0 1 6777 1
A 0 9 0 0 1 7033 1
A 0 9 0 0 1 6725 1
A 0 9 0 0 1 7032 1
A 0 9 0 0 1 6883 1
A 0 9 0 0 1 6724 1
A 0 9 0 0 1 6789 1
A 0 9 0 0 1 6861 1
A 0 9 0 0 1 7027 1
A 0 9 0 0 1 7028 1
A 0 9 0 0 1 6942 1
A 0 9 0 0 1 7019 1
A 0 9 0 0 1 7020 1
A 0 9 0 0 1 6866 1
A 0 9 0 0 1 7011 1
A 0 9 0 0 1 7012 1
A 0 9 0 0 1 6757 1
A 0 9 0 0 1 6946 1
A 0 9 0 0 1 7013 1
A 0 9 0 0 1 7014 1
A 0 9 0 0 1 6995 1
A 0 9 0 0 1 6996 1
A 0 9 0 0 1 6922 1
A 0 9 0 0 1 6997 1
A 0 9 0 0 1 6998 1
A 0 9 0 0 1 6999 1
A 0 9 0 0 1 6951 1
A 0 9 0 0 1 6926 1
A 0 9 0 0 1 6975 1
A 0 9 0 0 1 6976 1
A 0 9 0 0 1 6977 1
A 0 9 0 0 1 6978 1
A 0 9 0 0 1 6979 1
A 0 9 0 0 1 6956 1
A 0 9 0 0 1 6980 1
A 0 9 0 0 1 6928 1
A 0 9 0 0 1 6957 1
A 0 9 0 0 1 6958 1
A 0 9 0 0 1 6981 1
A 0 9 0 0 1 7000 1
A 0 9 0 0 1 6945 1
A 0 9 0 0 1 6943 1
A 0 9 0 0 1 7009 1
A 0 9 0 0 1 7015 1
A 0 9 0 0 1 6989 1
A 0 9 0 0 1 6914 1
A 0 9 0 0 1 7021 1
A 0 9 0 0 1 6805 1
A 0 9 0 0 1 7029 1
A 0 9 0 0 1 7030 1
A 0 9 0 0 1 6777 1
A 0 9 0 0 1 7033 1
A 0 9 0 0 1 6725 1
A 0 9 0 0 1 7032 1
A 0 9 0 0 1 6883 1
A 0 9 0 0 1 6724 1
A 0 9 0 0 1 6789 1
A 0 9 0 0 1 6861 1
A 0 9 0 0 1 7027 1
A 0 9 0 0 1 7028 1
A 0 9 0 0 1 6942 1
A 0 9 0 0 1 7019 1
A 0 9 0 0 1 7020 1
A 0 9 0 0 1 6866 1
A 0 9 0 0 1 7011 1
A 0 9 0 0 1 7012 1
A 0 9 0 0 1 6757 1
A 0 9 0 0 1 6946 1
A 0 9 0 0 1 7013 1
A 0 9 0 0 1 7014 1
A 0 9 0 0 1 6995 1
A 0 9 0 0 1 6996 1
A 0 9 0 0 1 6922 1
A 0 9 0 0 1 6997 1
A 0 9 0 0 1 6998 1
A 0 9 0 0 1 6999 1
A 0 9 0 0 1 6951 1
A 0 9 0 0 1 6926 1
A 0 9 0 0 1 6975 1
A 0 9 0 0 1 6976 1
A 0 9 0 0 1 6977 1
A 0 9 0 0 1 6978 1
A 0 9 0 0 1 6979 1
A 0 9 0 0 1 6956 1
A 0 9 0 0 1 6980 1
A 0 9 0 0 1 6928 1
A 0 9 0 0 1 6957 1
A 0 9 0 0 1 6958 1
A 0 9 0 0 1 6981 1
A 0 9 0 0 1 7000 1
A 0 9 0 0 1 6945 1
A 0 9 0 0 1 6943 1
A 0 9 0 0 1 7009 1
A 0 9 0 0 1 7015 1
A 0 9 0 0 1 6989 1
A 0 9 0 0 1 6914 1
A 0 9 0 0 1 7021 1
A 0 9 0 0 1 6805 1
A 0 9 0 0 1 7029 1
A 0 9 0 0 1 7030 1
A 0 9 0 0 1 6777 1
A 0 9 0 0 1 7033 1
A 0 9 0 0 1 6725 1
A 0 9 0 0 1 7032 1
A 0 9 0 0 1 6883 1
A 0 9 0 0 1 6724 1
A 0 9 0 0 1 6789 1
A 0 9 0 0 1 6861 1
A 0 9 0 0 1 7027 1
A 0 9 0 0 1 7028 1
A 0 9 0 0 1 6942 1
A 0 9 0 0 1 7019 1
A 0 9 0 0 1 7020 1
A 0 9 0 0 1 6866 1
A 0 9 0 0 1 7011 1
A 0 9 0 0 1 7012 1
A 0 9 0 0 1 6757 1
A 0 9 0 0 1 6946 1
A 0 9 0 0 1 7013 1
A 0 9 0 0 1 7014 1
A 0 9 0 0 1 6995 1
A 0 9 0 0 1 6996 1
A 0 9 0 0 1 6922 1
A 0 9 0 0 1 6997 1
A 0 9 0 0 1 6998 1
A 0 9 0 0 1 6999 1
A 0 9 0 0 1 6951 1
A 0 9 0 0 1 6926 1
A 0 9 0 0 1 6975 1
A 0 9 0 0 1 6976 1
A 0 9 0 0 1 6977 1
A 0 9 0 0 1 6978 1
A 0 9 0 0 1 6979 1
A 0 9 0 0 1 6956 1
A 0 9 0 0 1 6980 1
A 0 9 0 0 1 6928 1
A 0 9 0 0 1 6957 1
A 0 9 0 0 1 6958 1
A 0 9 0 0 1 6981 1
A 0 9 0 0 1 7000 1
A 0 9 0 0 1 6945 1
A 0 9 0 0 1 6943 1
A 0 9 0 0 1 7009 1
A 0 9 0 0 1 7015 1
A 0 9 0 0 1 6989 1
A 0 9 0 0 1 6914 1
A 0 9 0 0 1 7021 1
A 0 9 0 0 1 6805 1
A 0 9 0 0 1 7029 1
A 0 9 0 0 1 7030 1
A 0 9 0 0 1 6777 1
A 0 9 0 0 1 7033 1
A 0 9 0 0 1 6725 1
A 0 9 0 0 1 7032 1
A 0 9 0 0 1 6883 1
A 0 9 0 0 1 6724 1
A 0 9 0 0 1 6789 1
A 0 9 0 0 1 6861 1
A 0 9 0 0 1 7027 1
A 0 9 0 0 1 7028 1
A 0 9 0 0 1 6942 1
A 0 9 0 0 1 7019 1
A 0 9 0 0 1 7020 1
A 0 9 0 0 1 6866 1
A 0 9 0 0 1 7011 1
A 0 9 0 0 1 7012 1
A 0 9 0 0 1 6757 1
A 0 9 0 0 1 6946 1
A 0 9 0 0 1 7013 1
A 0 9 0 0 1 7014 1
A 0 9 0 0 1 6995 1
A 0 9 0 0 1 6996 1
A 0 9 0 0 1 6922 1
A 0 9 0 0 1 6997 1
A 0 9 0 0 1 6998 1
A 0 9 0 0 1 6999 1
A 0 9 0 0 1 6951 1
A 0 9 0 0 1 6926 1
A 0 9 0 0 1 6975 1
A 0 9 0 0 1 6976 1
A 0 9 0 0 1 6977 1
A 0 9 0 0 1 6978 1
A 0 9 0 0 1 6979 1
A 0 9 0 0 1 6956 1
A 0 9 0 0 1 6980 0
T 1996 378 0 3 0 0
R 2001 384 0 0
A 0 7 0 705 1 10 0
Z
