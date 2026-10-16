OF = OF or {}
OF.texshuffle = OF.texshuffle or {}

local texshuffle = OF.texshuffle

texshuffle.MODIFIER_KEY = "texshuffle"
local TARGETS = {
    { name = "bbh_seg7_texture_07000000", w = 32, h = 64, cite = "levels/bbh/merry_go_round/model.inc.c:31" },
    { name = "bbh_seg7_texture_07001000", w = 32, h = 32, cite = "levels/bbh/areas/1/3/model.inc.c:38" },
    { name = "bbh_seg7_texture_07001800", w = 32, h = 32, cite = "levels/bbh/areas/1/36/model.inc.c:21" },
    { name = "bbh_seg7_texture_07002000", w = 32, h = 64, cite = "levels/bbh/areas/1/18/model.inc.c:260" },
    { name = "bbh_seg7_texture_07003400", w = 32, h = 64, cite = "levels/bbh/coffin/model.inc.c:53" },
    { name = "bitdw_seg7_texture_07000000", w = 32, h = 32, cite = "levels/bitdw/ferris_platform/model.inc.c:12" },
    { name = "bitdw_seg7_texture_07000800", w = 32, h = 32, cite = "levels/bitdw/areas/1/quartzy_path_1/model.inc.c:21" },
    { name = "bitdw_seg7_texture_07001000", w = 32, h = 32, cite = "levels/bitdw/areas/1/wooden_platform/model.inc.c:64" },
    { name = "bitdw_seg7_texture_07001800", w = 32, h = 32, cite = "levels/bitdw/areas/1/quartz_crystal/model.inc.c:15" },
    { name = "bitfs_seg7_texture_07000000", w = 64, h = 32, cite = "levels/bitfs/sinking_cage_platform/model.inc.c:9" },
    { name = "bitfs_seg7_texture_07001000", w = 32, h = 32, cite = "levels/bitfs/elevator/model.inc.c:51" },
    { name = "bitfs_seg7_texture_07001800", w = 32, h = 32, cite = "levels/bitfs/areas/1/3/model.inc.c:45" },
    { name = "bits_seg7_texture_07000000", w = 32, h = 64, cite = "levels/bits/areas/1/19/model.inc.c:443" },
    { name = "bits_seg7_texture_07001000", w = 64, h = 32, cite = "levels/bits/areas/1/8/model.inc.c:111" },
    { name = "bits_seg7_texture_07002000", w = 32, h = 32, cite = "levels/bits/areas/1/25/model.inc.c:12" },
    { name = "bob_seg7_texture_07000000", w = 32, h = 32, cite = "levels/bob/areas/1/4/model.inc.c:29" },
    { name = "bob_seg7_texture_07000800", w = 32, h = 32, cite = "levels/bob/areas/1/2/model.inc.c:579" },
    { name = "bob_seg7_texture_07001000", w = 32, h = 32, cite = "levels/bob/areas/1/2/model.inc.c:530" },
    { name = "bob_seg7_texture_07001800", w = 32, h = 32, cite = "levels/bob/areas/1/2/model.inc.c:546" },
    { name = "bob_seg7_texture_07002000", w = 32, h = 32, cite = "levels/bob/areas/1/5/model.inc.c:396" },
    { name = "bowser_1_seg7_texture_07000000", w = 32, h = 64, cite = "levels/bowser_1/areas/1/1/model.inc.c:73" },
    { name = "bowser_1_seg7_texture_07001000", w = 32, h = 32, cite = "levels/bowser_1/areas/1/1/model.inc.c:53" },
    { name = "bowser_1_seg7_texture_07001800", w = 32, h = 32, cite = "levels/bowser_1/areas/1/1/model.inc.c:36" },
    { name = "bowser_2_seg7_texture_07000000", w = 32, h = 32, cite = "levels/bowser_2/areas/1/1/model.inc.c:27" },
    { name = "bowser_3_seg7_texture_07000000", w = 32, h = 32, cite = "levels/bowser_3/areas/1/bomb_stand/model.inc.c:18" },
    { name = "bowser_3_seg7_texture_07000800", w = 32, h = 32, cite = "levels/bowser_3/falling_platform_9/model.inc.c:27" },
    { name = "bowser_3_seg7_texture_07001000", w = 32, h = 64, cite = "levels/bowser_3/falling_platform_9/model.inc.c:43" },
    { name = "castle_grounds_seg7_texture_07000000", w = 32, h = 64, cite = "levels/castle_grounds/areas/1/4/model.inc.c:21" },
    { name = "castle_grounds_seg7_texture_07001000", w = 64, h = 32, cite = "levels/castle_grounds/areas/1/6/model.inc.c:66" },
    { name = "castle_grounds_seg7_texture_07002000", w = 64, h = 32, cite = "levels/castle_grounds/areas/1/6/model.inc.c:76" },
    { name = "castle_grounds_seg7_texture_0700C9E8", w = 32, h = 64, cite = "levels/castle_grounds/areas/1/12/model.inc.c:21" },
    { name = "castle_grounds_seg7_texture_0700D9E8", w = 32, h = 64, cite = "levels/castle_grounds/areas/1/12/model.inc.c:31" },
    { name = "ccm_seg7_texture_07000000", w = 32, h = 32, cite = "levels/ccm/areas/1/4/model.inc.c:150" },
    { name = "ccm_seg7_texture_07000900", w = 32, h = 32, cite = "levels/ccm/ropeway_lift/1.inc.c:32" },
    { name = "ccm_seg7_texture_07001100", w = 32, h = 32, cite = "levels/ccm/ropeway_lift/2.inc.c:69" },
    { name = "ccm_seg7_texture_07001900", w = 32, h = 32, cite = "levels/ccm/areas/1/8/model.inc.c:34" },
    { name = "ccm_seg7_texture_07002100", w = 32, h = 32, cite = "levels/ccm/snowman_head/2.inc.c:23" },
    { name = "ccm_seg7_texture_07002900", w = 32, h = 32, cite = "levels/ccm/snowman_head/2.inc.c:12" },
    { name = "ccm_seg7_texture_07003100", w = 32, h = 32, cite = "levels/ccm/areas/2/1/model.inc.c:624" },
    { name = "ccm_seg7_texture_07003B00", w = 32, h = 32, cite = "levels/ccm/areas/2/7/model.inc.c:55" },
    { name = "ccm_seg7_texture_07004300", w = 32, h = 32, cite = "levels/ccm/areas/2/2/model.inc.c:210" },
    { name = "ccm_seg7_texture_07004B00", w = 32, h = 32, cite = "levels/ccm/areas/2/3/model.inc.c:15" },
    { name = "ccm_seg7_texture_07011958", w = 32, h = 32, cite = "levels/ccm/snowman_base/model.inc.c:39" },
    { name = "inside_castle_seg7_texture_07000800", w = 32, h = 32, cite = "levels/castle_inside/areas/1/6/model.inc.c:15" },
    { name = "inside_castle_seg7_texture_07001000", w = 32, h = 64, cite = "levels/castle_inside/areas/3/5/model.inc.c:18" },
    { name = "inside_castle_seg7_texture_07002000", w = 32, h = 64, cite = "levels/castle_inside/areas/1/11/model.inc.c:9" },
    { name = "inside_castle_seg7_texture_07003000", w = 32, h = 32, cite = "levels/castle_inside/areas/3/10/model.inc.c:15" },
    { name = "inside_castle_seg7_texture_07003800", w = 32, h = 64, cite = "levels/castle_inside/star_door/model.inc.c:36" },
    { name = "inside_castle_seg7_texture_07004800", w = 32, h = 64, cite = "levels/castle_inside/star_door/model.inc.c:46" },
    { name = "inside_castle_seg7_texture_07005800", w = 32, h = 32, cite = "levels/castle_inside/star_door/model.inc.c:21" },
    { name = "inside_castle_seg7_texture_07006000", w = 32, h = 32, cite = "levels/castle_inside/areas/2/9/model.inc.c:465" },
    { name = "inside_castle_seg7_texture_07006800", w = 32, h = 32, cite = "levels/castle_inside/areas/2/9/model.inc.c:487" },
    { name = "inside_castle_seg7_texture_07007000", w = 32, h = 32, cite = "levels/castle_inside/areas/2/9/model.inc.c:454" },
    { name = "inside_castle_seg7_texture_07007800", w = 32, h = 32, cite = "levels/castle_inside/areas/2/9/model.inc.c:476" },
    { name = "inside_castle_seg7_texture_07008000", w = 32, h = 32, cite = "levels/castle_inside/areas/2/14/model.inc.c:102" },
    { name = "inside_castle_seg7_texture_07008800", w = 32, h = 32, cite = "levels/castle_inside/areas/2/14/model.inc.c:128" },
    { name = "inside_castle_seg7_texture_07009000", w = 32, h = 32, cite = "levels/castle_inside/areas/2/14/model.inc.c:154" },
    { name = "inside_castle_seg7_texture_07009800", w = 32, h = 32, cite = "levels/castle_inside/areas/2/14/model.inc.c:180" },
    { name = "pss_seg7_texture_07000000", w = 32, h = 32, cite = "levels/pss/areas/1/6/model.inc.c:37" },
    { name = "pss_seg7_texture_07000800", w = 32, h = 32, cite = "levels/pss/areas/1/5/model.inc.c:24" },
    { name = "pss_seg7_texture_07001000", w = 32, h = 32, cite = "levels/pss/areas/1/7/model.inc.c:15" },
    { name = "rr_seg7_texture_07000800", w = 64, h = 32, cite = "levels/rr/cruiser_wing/model.inc.c:9" },
    { name = "rr_seg7_texture_07001800", w = 32, h = 32, cite = "levels/rr/areas/1/20/model.inc.c:134" },
    { name = "sl_seg7_texture_07000000", w = 32, h = 32, cite = "levels/sl/areas/1/7/model.inc.c:179" },
    { name = "sl_seg7_texture_07000800", w = 32, h = 32, cite = "levels/sl/areas/1/1/model.inc.c:341" },
    { name = "sl_seg7_texture_07001000", w = 32, h = 32, cite = "levels/sl/unused_cracked_ice/model.inc.c:15" },
    { name = "sl_seg7_texture_07001800", w = 32, h = 32, cite = "levels/sl/areas/1/1/model.inc.c:354" },
    { name = "sl_seg7_texture_07002000", w = 32, h = 32, cite = "levels/sl/areas/1/7/model.inc.c:189" },
    { name = "ssl_seg7_texture_07000000", w = 32, h = 32, cite = "levels/ssl/areas/1/1/model.inc.c:651" },
    { name = "ssl_seg7_texture_07000800", w = 32, h = 32, cite = "levels/ssl/areas/1/4/model.inc.c:9" },
    { name = "ssl_seg7_texture_07001800", w = 32, h = 32, cite = "levels/ssl/areas/3/1/model.inc.c:245" },
    { name = "ssl_seg7_texture_07002800", w = 32, h = 64, cite = "levels/ssl/grindel/model.inc.c:31" },
    { name = "ssl_seg7_texture_07003800", w = 32, h = 32, cite = "levels/ssl/grindel/model.inc.c:76" },
    { name = "ssl_seg7_texture_0700BFA8", w = 32, h = 32, cite = "levels/ssl/tox_box/model.inc.c:39" },
    { name = "ssl_seg7_texture_0700C7A8", w = 32, h = 64, cite = "levels/ssl/tox_box/model.inc.c:57" },
    { name = "ssl_seg7_texture_0700D7A8", w = 32, h = 64, cite = "levels/ssl/tox_box/model.inc.c:83" },
    { name = "ssl_seg7_texture_0700E7A8", w = 32, h = 64, cite = "levels/ssl/tox_box/model.inc.c:70" },
    { name = "thi_seg7_texture_07000000", w = 32, h = 32, cite = "levels/thi/areas/3/3/model.inc.c:48" },
    { name = "thi_seg7_texture_07000800", w = 32, h = 32, cite = "levels/thi/areas/1/6/model.inc.c:15" },
    { name = "totwc_seg7_texture_07000000", w = 32, h = 64, cite = "levels/totwc/areas/1/1/model.inc.c:357" },
    { name = "totwc_seg7_texture_07001000", w = 32, h = 32, cite = "levels/totwc/areas/1/3/model.inc.c:24" },
    { name = "totwc_seg7_texture_07001800", w = 32, h = 32, cite = "levels/totwc/areas/1/1/model.inc.c:163" },
    { name = "totwc_seg7_texture_07002000", w = 32, h = 32, cite = "levels/totwc/cloud/model.inc.c:9" },
    { name = "ttc_seg7_texture_07000000", w = 32, h = 32, cite = "levels/ttc/small_gear/model.inc.c:9" },
    { name = "ttm_seg7_texture_07000000", w = 32, h = 32, cite = "levels/ttm/areas/1/3/2.inc.c:18" },
    { name = "ttm_seg7_texture_07000800", w = 32, h = 32, cite = "levels/ttm/areas/1/3/1.inc.c:58" },
    { name = "ttm_seg7_texture_07001000", w = 32, h = 32, cite = "levels/ttm/areas/1/17/1.inc.c:21" },
    { name = "ttm_seg7_texture_07001800", w = 32, h = 32, cite = "levels/ttm/areas/1/17/2.inc.c:30" },
    { name = "ttm_seg7_texture_07002000", w = 32, h = 32, cite = "levels/ttm/rolling_log/model.inc.c:24" },
    { name = "ttm_seg7_texture_07002800", w = 32, h = 32, cite = "levels/ttm/areas/1/1/model.inc.c:570" },
    { name = "ttm_seg7_texture_0702AD30", w = 32, h = 32, cite = "levels/ttm/slide_exit_podium/model.inc.c:45" },
    { name = "vcutm_seg7_texture_07000000", w = 32, h = 32, cite = "levels/vcutm/areas/1/2/model.inc.c:15" },
    { name = "vcutm_seg7_texture_07000800", w = 64, h = 32, cite = "levels/vcutm/areas/1/3/model.inc.c:39" },
    { name = "vcutm_seg7_texture_07001800", w = 32, h = 64, cite = "levels/vcutm/seesaw/model.inc.c:27" },
    { name = "vcutm_seg7_texture_07002800", w = 32, h = 32, cite = "levels/vcutm/areas/1/1/model.inc.c:481" },
    { name = "wf_seg7_texture_07000000", w = 32, h = 32, cite = "levels/wf/areas/1/11/model.inc.c:18" },
    { name = "wf_seg7_texture_07000800", w = 32, h = 32, cite = "levels/wf/areas/1/2/model.inc.c:15" },
    { name = "wf_seg7_texture_07001000", w = 32, h = 32, cite = "levels/wf/areas/1/11/model.inc.c:30" },
    { name = "wf_seg7_texture_07001800", w = 32, h = 32, cite = "levels/wf/areas/1/10/1.inc.c:57" },
    { name = "wf_seg7_texture_07002000", w = 32, h = 32, cite = "levels/wf/large_bomp/model.inc.c:46" },
    { name = "wmotr_seg7_texture_07000000", w = 32, h = 32, cite = "levels/wmotr/areas/1/model.inc.c:479" },
    { name = "wmotr_seg7_texture_07000C00", w = 32, h = 32, cite = "levels/wmotr/areas/1/model.inc.c:517" },
}

local SHARED_TARGETS = {
    { name = "cave_09000000", w = 32, h = 64, cite = "levels/hmc/areas/1/11/model.inc.c:450" },
    { name = "cave_09001000", w = 32, h = 32, cite = "levels/hmc/areas/1/18/model.inc.c:25" },
    { name = "cave_09001800", w = 32, h = 64, cite = "levels/hmc/areas/1/1/model.inc.c:235" },
    { name = "cave_09002800", w = 32, h = 32, cite = "levels/hmc/elevator_platform/model.inc.c:13" },
    { name = "cave_09003000", w = 32, h = 32, cite = "levels/hmc/areas/1/12/model.inc.c:7" },
    { name = "cave_09003800", w = 32, h = 64, cite = "levels/cotmc/areas/1/1/model.inc.c:467" },
    { name = "cave_09004800", w = 64, h = 32, cite = "levels/hmc/areas/1/1/model.inc.c:263" },
    { name = "cave_09005800", w = 32, h = 64, cite = "levels/cotmc/areas/1/1/model.inc.c:520" },
    { name = "cave_09006800", w = 32, h = 32, cite = "levels/cotmc/areas/1/1/model.inc.c:238" },
    { name = "cave_09007000", w = 32, h = 32, cite = "levels/hmc/areas/1/14/model.inc.c:25" },
    { name = "cave_09007800", w = 32, h = 64, cite = "levels/cotmc/areas/1/1/model.inc.c:532" },
    { name = "cave_09008800", w = 32, h = 64, cite = "levels/hmc/areas/1/11/model.inc.c:397" },
    { name = "cave_09009800", w = 32, h = 32, cite = "levels/hmc/areas/1/1/model.inc.c:109" },
    { name = "cave_0900A000", w = 32, h = 32, cite = "levels/hmc/areas/1/20/model.inc.c:43" },
    { name = "cave_0900A800", w = 32, h = 64, cite = "levels/hmc/areas/1/11/model.inc.c:470" },
    { name = "generic_09000000", w = 32, h = 32, cite = "levels/ssl/areas/1/3/model.inc.c:13" },
    { name = "generic_09000800", w = 32, h = 32, cite = "levels/ssl/areas/1/1/model.inc.c:365" },
    { name = "generic_09001000", w = 32, h = 32, cite = "levels/ssl/areas/1/1/model.inc.c:555" },
    { name = "generic_09001800", w = 32, h = 32, cite = "levels/bob/areas/1/2/model.inc.c:365" },
    { name = "generic_09002000", w = 32, h = 32, cite = "levels/bob/areas/1/2/model.inc.c:277" },
    { name = "generic_09002800", w = 32, h = 32, cite = "levels/ssl/areas/1/1/model.inc.c:531" },
    { name = "generic_09003000", w = 32, h = 32, cite = "levels/bob/areas/1/2/model.inc.c:491" },
    { name = "generic_09003800", w = 32, h = 32, cite = "levels/bob/areas/1/2/model.inc.c:247" },
    { name = "generic_09004000", w = 32, h = 32, cite = "levels/ssl/areas/1/1/model.inc.c:422" },
    { name = "generic_09004800", w = 32, h = 32, cite = "levels/bob/areas/1/2/model.inc.c:463" },
    { name = "generic_09005000", w = 32, h = 32, cite = "levels/bob/areas/1/2/model.inc.c:436" },
    { name = "generic_09005800", w = 32, h = 32, cite = "levels/bob/areas/1/1/model.inc.c:79" },
    { name = "generic_09006000", w = 32, h = 64, cite = "levels/bob/areas/1/1/model.inc.c:205" },
    { name = "generic_09007800", w = 32, h = 32, cite = "levels/ssl/areas/2/1/model.inc.c:799" },
    { name = "generic_09008000", w = 32, h = 32, cite = "levels/ssl/areas/1/2/model.inc.c:70" },
    { name = "generic_09008800", w = 32, h = 32, cite = "levels/bob/areas/1/4/model.inc.c:16" },
    { name = "generic_09009000", w = 32, h = 32, cite = "levels/bob/areas/1/5/model.inc.c:145" },
    { name = "generic_09009800", w = 32, h = 32, cite = "levels/bob/areas/1/1/model.inc.c:184" },
    { name = "generic_0900A000", w = 32, h = 32, cite = "levels/bob/areas/1/5/model.inc.c:405" },
    { name = "generic_0900A800", w = 32, h = 32, cite = "levels/ssl/areas/1/1/model.inc.c:247" },
    { name = "grass_09000000", w = 32, h = 32, cite = "levels/thi/areas/3/4/model.inc.c:7" },
    { name = "grass_09000800", w = 32, h = 32, cite = "levels/wdw/areas/1/1/model.inc.c:316" },
    { name = "grass_09001000", w = 32, h = 32, cite = "levels/wdw/areas/1/1/model.inc.c:403" },
    { name = "grass_09001800", w = 32, h = 32, cite = "levels/thi/areas/3/2/model.inc.c:137" },
    { name = "grass_09002000", w = 32, h = 32, cite = "levels/wdw/areas/2/1/model.inc.c:737" },
    { name = "grass_09002800", w = 32, h = 32, cite = "levels/wf/areas/1/15/1.inc.c:66" },
    { name = "grass_09003000", w = 32, h = 32, cite = "levels/thi/areas/1/1/model.inc.c:439" },
    { name = "grass_09003800", w = 32, h = 32, cite = "levels/thi/areas/1/1/model.inc.c:205" },
    { name = "grass_09004000", w = 32, h = 32, cite = "levels/wdw/areas/1/1/model.inc.c:527" },
    { name = "grass_09004800", w = 32, h = 32, cite = "levels/thi/areas/1/1/model.inc.c:269" },
    { name = "grass_09005000", w = 32, h = 32, cite = "levels/thi/areas/1/1/model.inc.c:291" },
    { name = "grass_09005800", w = 32, h = 32, cite = "levels/thi/areas/1/1/model.inc.c:349" },
    { name = "grass_09006800", w = 32, h = 32, cite = "levels/thi/areas/1/2/model.inc.c:85" },
    { name = "grass_09007000", w = 32, h = 32, cite = "levels/wdw/areas/1/1/model.inc.c:602" },
    { name = "grass_09007800", w = 32, h = 32, cite = "levels/wdw/areas/1/1/model.inc.c:691" },
    { name = "grass_09008000", w = 32, h = 32, cite = "levels/thi/areas/1/1/model.inc.c:554" },
    { name = "grass_09008800", w = 32, h = 32, cite = "levels/wdw/areas/1/1/model.inc.c:483" },
    { name = "grass_09009000", w = 32, h = 32, cite = "levels/wdw/areas/1/1/model.inc.c:450" },
    { name = "grass_09009800", w = 32, h = 32, cite = "levels/wdw/areas/1/1/model.inc.c:817" },
    { name = "grass_0900A000", w = 32, h = 32, cite = "levels/thi/areas/1/3/model.inc.c:19" },
    { name = "grass_0900A800", w = 32, h = 32, cite = "levels/thi/areas/1/1/model.inc.c:568" },
    { name = "inside_09000000", w = 64, h = 32, cite = "levels/castle_inside/areas/1/2/model.inc.c:492" },
    { name = "inside_09001000", w = 64, h = 32, cite = "levels/castle_inside/areas/1/18/model.inc.c:182" },
    { name = "inside_09002000", w = 32, h = 64, cite = "levels/castle_inside/areas/2/3/model.inc.c:98" },
    { name = "inside_09003000", w = 32, h = 32, cite = "levels/castle_inside/areas/1/10/model.inc.c:465" },
    { name = "inside_09003800", w = 32, h = 32, cite = "levels/castle_inside/areas/1/13/model.inc.c:128" },
    { name = "inside_09004000", w = 32, h = 32, cite = "levels/castle_inside/areas/1/10/model.inc.c:407" },
    { name = "inside_09004800", w = 32, h = 32, cite = "levels/castle_inside/areas/2/8/model.inc.c:100" },
    { name = "inside_09005000", w = 32, h = 32, cite = "levels/castle_inside/areas/1/10/model.inc.c:434" },
    { name = "inside_09005800", w = 32, h = 32, cite = "levels/castle_inside/areas/2/9/model.inc.c:420" },
    { name = "inside_09006000", w = 32, h = 64, cite = "levels/castle_inside/areas/3/6/model.inc.c:361" },
    { name = "inside_09007000", w = 32, h = 64, cite = "levels/castle_inside/areas/1/13/model.inc.c:188" },
    { name = "inside_09008000", w = 32, h = 32, cite = "levels/castle_inside/areas/1/18/model.inc.c:122" },
    { name = "inside_09008800", w = 32, h = 32, cite = "levels/castle_inside/areas/1/16/model.inc.c:13" },
    { name = "inside_09009000", w = 32, h = 64, cite = "levels/castle_inside/areas/3/1/model.inc.c:587" },
    { name = "inside_0900A000", w = 32, h = 64, cite = "levels/castle_inside/areas/1/13/model.inc.c:165" },
    { name = "inside_0900B000", w = 32, h = 32, cite = "levels/castle_inside/areas/1/21/model.inc.c:13" },
    { name = "inside_0900B800", w = 64, h = 32, cite = "levels/castle_inside/areas/2/2/model.inc.c:493" },
    { name = "machine_09000000", w = 32, h = 32, cite = "levels/ttc/areas/1/3/model.inc.c:142" },
    { name = "machine_09000800", w = 32, h = 32, cite = "levels/ttc/clock_hand/model.inc.c:40" },
    { name = "machine_09001000", w = 32, h = 32, cite = "levels/ttc/areas/1/1/model.inc.c:893" },
    { name = "machine_09001800", w = 32, h = 32, cite = "levels/ttc/pendulum/model.inc.c:40" },
    { name = "machine_09002000", w = 32, h = 32, cite = "levels/ttc/areas/1/1/model.inc.c:1038" },
    { name = "machine_09002800", w = 32, h = 32, cite = "levels/ttc/areas/1/1/model.inc.c:826" },
    { name = "machine_09003000", w = 32, h = 32, cite = "levels/ttc/areas/1/1/model.inc.c:969" },
    { name = "machine_09003800", w = 32, h = 32, cite = "levels/ttc/areas/1/1/model.inc.c:671" },
    { name = "machine_09004000", w = 32, h = 64, cite = "levels/ttc/areas/1/3/model.inc.c:309" },
    { name = "machine_09005000", w = 32, h = 32, cite = "levels/ttc/elevator_platform/model.inc.c:37" },
    { name = "machine_09005800", w = 32, h = 32, cite = "levels/ttc/large_treadmill/model.inc.c:28" },
    { name = "machine_09006000", w = 32, h = 32, cite = "levels/ttc/large_treadmill/model.inc.c:41" },
    { name = "machine_09006800", w = 32, h = 32, cite = "levels/ttc/areas/1/1/model.inc.c:793" },
    { name = "machine_09007000", w = 32, h = 32, cite = "levels/ttc/areas/1/1/model.inc.c:530" },
    { name = "machine_09008400", w = 32, h = 32, cite = "levels/ttc/areas/1/1/model.inc.c:625" },
    { name = "mountain_09000000", w = 32, h = 32, cite = "levels/pss/areas/1/1/model.inc.c:573" },
    { name = "mountain_09000800", w = 64, h = 32, cite = "levels/ttm/areas/2/2/model.inc.c:19" },
    { name = "mountain_09001800", w = 32, h = 64, cite = "levels/pss/areas/1/1/model.inc.c:745" },
    { name = "mountain_09002800", w = 32, h = 32, cite = "levels/ttm/blue_smiley/model.inc.c:7" },
    { name = "mountain_09003000", w = 32, h = 32, cite = "levels/ttm/yellow_smiley/model.inc.c:7" },
    { name = "mountain_09003800", w = 32, h = 32, cite = "levels/ttm/areas/1/1/model.inc.c:491" },
    { name = "mountain_09004000", w = 32, h = 32, cite = "levels/ttm/areas/1/1/model.inc.c:244" },
    { name = "mountain_09004800", w = 32, h = 32, cite = "levels/ttm/areas/1/3/1.inc.c:28" },
    { name = "mountain_09005000", w = 32, h = 32, cite = "levels/ttm/areas/1/1/model.inc.c:479" },
    { name = "mountain_09005800", w = 32, h = 64, cite = "levels/pss/areas/1/1/model.inc.c:712" },
    { name = "mountain_09006800", w = 32, h = 32, cite = "levels/ttm/areas/2/1/model.inc.c:349" },
    { name = "mountain_09007000", w = 32, h = 32, cite = "levels/pss/areas/1/2/model.inc.c:65" },
    { name = "mountain_09007800", w = 32, h = 32, cite = "levels/pss/areas/1/3/model.inc.c:13" },
    { name = "mountain_09008000", w = 32, h = 32, cite = "levels/ttm/areas/1/16/2.inc.c:7" },
    { name = "mountain_09008800", w = 64, h = 32, cite = "levels/ttm/areas/2/1/model.inc.c:530" },
    { name = "mountain_09009800", w = 32, h = 32, cite = "levels/ttm/star_smiley/model.inc.c:7" },
    { name = "mountain_0900A000", w = 32, h = 32, cite = "levels/ttm/areas/1/17/1.inc.c:35" },
    { name = "mountain_0900A800", w = 32, h = 32, cite = "levels/ttm/areas/1/21/1.inc.c:58" },
    { name = "mountain_0900B000", w = 32, h = 32, cite = "levels/ttm/moon_smiley/model.inc.c:7" },
    { name = "mountain_0900B800", w = 32, h = 32, cite = "levels/ttm/areas/2/1/model.inc.c:381" },
    { name = "mountain_0900C000", w = 32, h = 32, cite = "levels/pss/areas/1/1/model.inc.c:364" },
    { name = "outside_09000000", w = 32, h = 32, cite = "levels/castle_courtyard/areas/1/1/model.inc.c:406" },
    { name = "outside_09000800", w = 32, h = 32, cite = "levels/castle_courtyard/areas/1/1/model.inc.c:297" },
    { name = "outside_09001000", w = 64, h = 32, cite = "levels/castle_courtyard/areas/1/1/model.inc.c:489" },
    { name = "outside_09002000", w = 32, h = 64, cite = "levels/castle_grounds/areas/1/1/model.inc.c:354" },
    { name = "outside_09003000", w = 32, h = 32, cite = "levels/castle_courtyard/areas/1/1/model.inc.c:279" },
    { name = "outside_09003800", w = 32, h = 32, cite = "levels/castle_grounds/areas/1/2/model.inc.c:311" },
    { name = "outside_09004000", w = 32, h = 32, cite = "levels/castle_courtyard/areas/1/1/model.inc.c:361" },
    { name = "outside_09004800", w = 32, h = 64, cite = "levels/castle_courtyard/areas/1/1/model.inc.c:448" },
    { name = "outside_09005800", w = 32, h = 32, cite = "levels/castle_grounds/areas/1/7/model.inc.c:7" },
    { name = "outside_09006000", w = 32, h = 32, cite = "levels/castle_courtyard/areas/1/1/model.inc.c:435" },
    { name = "outside_09006800", w = 64, h = 32, cite = "levels/castle_courtyard/areas/1/1/model.inc.c:542" },
    { name = "outside_09007800", w = 32, h = 32, cite = "levels/castle_courtyard/areas/1/spire/model.inc.c:22" },
    { name = "outside_09008000", w = 32, h = 32, cite = "levels/castle_grounds/areas/1/2/model.inc.c:221" },
    { name = "outside_09008800", w = 32, h = 32, cite = "levels/castle_courtyard/areas/1/1/model.inc.c:425" },
    { name = "outside_09009000", w = 32, h = 32, cite = "levels/castle_courtyard/areas/1/1/model.inc.c:252" },
    { name = "outside_09009800", w = 32, h = 32, cite = "levels/castle_grounds/areas/1/2/model.inc.c:270" },
    { name = "outside_0900A000", w = 32, h = 32, cite = "levels/castle_courtyard/areas/1/1/model.inc.c:374" },
    { name = "outside_0900A800", w = 32, h = 32, cite = "levels/castle_courtyard/areas/1/3/model.inc.c:10" },
    { name = "outside_0900B400", w = 32, h = 32, cite = "levels/castle_grounds/areas/1/2/model.inc.c:297" },
    { name = "sky_09000000", w = 32, h = 32, cite = "levels/bitdw/areas/1/wooden_bridge_and_fences/model.inc.c:37" },
    { name = "sky_09000800", w = 32, h = 32, cite = "levels/bitdw/areas/1/narrow_path_platform/model.inc.c:19" },
    { name = "sky_09001000", w = 32, h = 32, cite = "levels/bitdw/areas/1/starting_platform/model.inc.c:25" },
    { name = "sky_09001800", w = 32, h = 32, cite = "levels/bitdw/areas/1/large_platform/model.inc.c:28" },
    { name = "sky_09002000", w = 32, h = 64, cite = "levels/bitdw/square_platform/model.inc.c:10" },
    { name = "sky_09003000", w = 32, h = 32, cite = "levels/bitfs/sliding_platform/model.inc.c:10" },
    { name = "sky_09003800", w = 64, h = 32, cite = "levels/bitdw/areas/1/track_for_pyramid_platforms/model.inc.c:10" },
    { name = "sky_09004800", w = 32, h = 32, cite = "levels/bitdw/areas/1/octogonal_platform/model.inc.c:69" },
    { name = "sky_09005000", w = 32, h = 32, cite = "levels/bitdw/areas/1/quartzy_path_fences/model.inc.c:10" },
    { name = "sky_09005800", w = 32, h = 32, cite = "levels/rr/areas/1/13/model.inc.c:19" },
    { name = "sky_09006000", w = 32, h = 32, cite = "levels/bitdw/areas/1/wooden_bridge_and_fences/model.inc.c:26" },
    { name = "sky_09007000", w = 32, h = 32, cite = "levels/bitdw/areas/1/large_platform/model.inc.c:49" },
    { name = "sky_09007800", w = 32, h = 32, cite = "levels/bitdw/areas/1/platforms_and_tilting/model.inc.c:152" },
    { name = "sky_09008000", w = 32, h = 32, cite = "levels/bitdw/collapsing_stairs_1/model.inc.c:19" },
    { name = "snow_09000000", w = 32, h = 32, cite = "levels/ccm/areas/1/4/model.inc.c:93" },
    { name = "snow_09000800", w = 32, h = 32, cite = "levels/ccm/areas/1/10/3.inc.c:13" },
    { name = "snow_09001000", w = 32, h = 64, cite = "levels/ccm/areas/1/3/model.inc.c:139" },
    { name = "snow_09002000", w = 32, h = 32, cite = "levels/ccm/areas/1/1/model.inc.c:403" },
    { name = "snow_09002800", w = 32, h = 32, cite = "levels/ccm/areas/1/1/model.inc.c:644" },
    { name = "snow_09003000", w = 32, h = 32, cite = "levels/ccm/areas/1/1/model.inc.c:469" },
    { name = "snow_09004000", w = 32, h = 32, cite = "levels/ccm/areas/1/7/2.inc.c:10" },
    { name = "snow_09004800", w = 32, h = 32, cite = "levels/ccm/areas/1/1/model.inc.c:671" },
    { name = "snow_09005000", w = 32, h = 32, cite = "levels/ccm/areas/1/6/1.inc.c:71" },
    { name = "snow_09005800", w = 32, h = 32, cite = "levels/ccm/areas/1/10/2.inc.c:13" },
    { name = "snow_09006000", w = 32, h = 32, cite = "levels/ccm/areas/1/1/model.inc.c:371" },
    { name = "snow_09006800", w = 32, h = 32, cite = "levels/ccm/areas/1/4/model.inc.c:111" },
    { name = "snow_09007000", w = 64, h = 32, cite = "levels/ccm/areas/1/10/2.inc.c:24" },
    { name = "snow_09008000", w = 32, h = 32, cite = "levels/ccm/areas/1/2/model.inc.c:13" },
    { name = "snow_09008800", w = 32, h = 32, cite = "levels/ccm/areas/1/1/model.inc.c:259" },
    { name = "spooky_09000000", w = 32, h = 32, cite = "levels/bbh/areas/1/25/model.inc.c:10" },
    { name = "spooky_09000800", w = 32, h = 64, cite = "levels/bbh/areas/1/18/model.inc.c:189" },
    { name = "spooky_09001800", w = 32, h = 64, cite = "levels/bbh/areas/1/1/model.inc.c:314" },
    { name = "spooky_09002800", w = 32, h = 64, cite = "levels/bbh/areas/1/12/model.inc.c:175" },
    { name = "spooky_09003800", w = 32, h = 64, cite = "levels/bbh/areas/1/1/model.inc.c:231" },
    { name = "spooky_09004800", w = 32, h = 32, cite = "levels/bbh/areas/1/1/model.inc.c:202" },
    { name = "spooky_09005000", w = 32, h = 64, cite = "levels/bbh/areas/1/16/model.inc.c:189" },
    { name = "spooky_09006000", w = 32, h = 32, cite = "levels/bbh/areas/1/14/model.inc.c:13" },
    { name = "spooky_09006800", w = 32, h = 32, cite = "levels/bbh/areas/1/10/model.inc.c:19" },
    { name = "spooky_09007000", w = 64, h = 32, cite = "levels/bbh/areas/1/28/model.inc.c:194" },
    { name = "spooky_09008000", w = 32, h = 32, cite = "levels/bbh/areas/1/13/model.inc.c:7" },
    { name = "spooky_09008800", w = 32, h = 32, cite = "levels/bbh/areas/1/1/model.inc.c:136" },
    { name = "spooky_09009000", w = 64, h = 32, cite = "levels/bbh/areas/1/1/model.inc.c:363" },
    { name = "spooky_0900A000", w = 32, h = 32, cite = "levels/bbh/areas/1/1/model.inc.c:219" },
}
for _, target in ipairs(SHARED_TARGETS) do table.insert(TARGETS, target) end

local EVERY_TARGET = {
    { w = 32, h = 32, names = {
        "amp_seg8_texture_08001318", "amp_seg8_texture_08001B18", "amp_seg8_texture_08002318",
        "blue_coin_switch_seg8_texture_08000418", "blue_fish_seg3_texture_0301B5E0", "bobomb_seg8_texture_08021A60",
        "bobomb_seg8_texture_08022260", "bomb_seg6_texture_06059AC0", "boo_seg5_texture_0500AB40",
        "boo_castle_seg6_texture_06016670", "book_seg5_texture_05002570", "bookend_seg5_texture_05001060",
        "bowser_seg6_texture_0601F438", "bowser_seg6_texture_06020C38", "bowser_seg6_texture_06022438",
        "bowser_seg6_texture_06023C38", "bowser_seg6_texture_06025438", "bowser_seg6_texture_06025C38",
        "bowser_seg6_texture_06028438", "breakable_box_seg8_texture_08011A90", "breakable_box_seg8_texture_08012290",
        "bub_seg6_texture_0600E2A8", "bub_seg6_texture_0600EAA8", "bubba_seg5_texture_05001408",
        "bubba_seg5_texture_05001C08", "bubble_seg4_texture_0401CD60", "bubble_seg4_texture_0401D560",
        "bully_seg5_texture_05002468", "cannon_barrel_seg8_texture_080058A8", "cannon_base_seg8_texture_080049B8",
        "cannon_lid_seg8_texture_08004058", "chain_ball_seg6_texture_06020AE8", "chain_chomp_seg6_texture_060213D0",
        "chain_chomp_seg6_texture_06021BD0", "chain_chomp_seg6_texture_060223D0", "chain_chomp_seg6_texture_06022BD0",
        "chain_chomp_seg6_texture_060233D0", "chair_seg5_texture_05003060", "chair_seg5_texture_05003860",
        "chair_seg5_texture_05004460", "checkerboard_platform_seg8_texture_0800CC40", "chilly_chief_seg6_texture_06002060",
        "chuckya_seg8_texture_08007778", "clam_shell_seg5_texture_05000030", "clam_shell_seg5_texture_05000830",
        "cyan_fish_seg6_texture_0600D468", "door_seg3_texture_0300CD10", "door_seg3_texture_0300E510",
        "door_seg3_texture_0300FD10", "door_seg3_texture_03011510", "door_seg3_texture_03011D10",
        "door_seg3_texture_03012510", "door_seg3_texture_03012D10", "dorrie_seg6_texture_0600ADA0",
        "exclamation_box_seg8_texture_08012E28", "exclamation_box_seg8_texture_08014628", "exclamation_box_seg8_texture_08015E28",
        "exclamation_box_seg8_texture_08017628", "exclamation_box_outline_seg8_texture_08025168", "explosion_seg3_texture_03000A08",
        "explosion_seg3_texture_03001208", "explosion_seg3_texture_03001A08", "explosion_seg3_texture_03002208",
        "explosion_seg3_texture_03002A08", "explosion_seg3_texture_03003208", "explosion_seg3_texture_03003A08",
        "eyerok_seg5_texture_05008D40", "eyerok_seg5_texture_05009540", "eyerok_seg5_texture_05009D40",
        "eyerok_seg5_texture_0500A540", "eyerok_seg5_texture_0500AD40", "flyguy_seg8_texture_0800F088",
        "goomba_seg8_texture_08019530", "goomba_seg8_texture_08019D30", "goomba_seg8_texture_0801A530",
        "haunted_cage_seg5_texture_0500C288", "haunted_cage_seg5_texture_0500CA88", "haunted_cage_seg5_texture_0500DA88",
        "haunted_cage_seg5_texture_0500E288", "heart_seg8_texture_0800D7E0", "heave_ho_seg5_texture_0500E9C8",
        "heave_ho_seg5_texture_0500F1C8", "heave_ho_seg5_texture_050109C8", "heave_ho_seg5_texture_050113C8",
        "hoot_seg5_texture_05000A20", "hoot_seg5_texture_05001E50", "hoot_seg5_texture_05002650",
        "king_bobomb_seg5_texture_05002078", "king_bobomb_seg5_texture_05005878", "klepto_seg5_texture_05000008",
        "klepto_seg5_texture_05000808", "klepto_seg5_texture_05003008", "koopa_seg6_texture_06002648",
        "koopa_seg6_texture_06002E48", "koopa_seg6_texture_06003648", "koopa_seg6_texture_06003E48",
        "koopa_seg6_texture_06004648", "koopa_seg6_texture_06004E48", "koopa_seg6_texture_06005648",
        "koopa_flag_seg6_texture_06000048", "koopa_shell_seg8_texture_080274A0", "koopa_shell_seg8_texture_08027CA0",
        "lakitu_seg6_texture_06000000", "lakitu_seg6_texture_06002800", "lakitu_seg6_texture_06003000",
        "lakitu_enemy_seg5_texture_0500ECE0", "lakitu_enemy_seg5_texture_050114E0", "lakitu_enemy_seg5_texture_05011CE0",
        "mad_piano_seg5_texture_05006AF0", "manta_seg5_texture_050017A0", "manta_seg5_texture_05002FA0",
        "mips_seg6_texture_0600FB80", "moneybag_seg6_texture_060049B0", "monty_mole_seg5_texture_05000970",
        "monty_mole_seg5_texture_05001170", "monty_mole_seg5_texture_05001970", "monty_mole_seg5_texture_05002170",
        "monty_mole_seg5_texture_05002970", "mr_i_iris_seg6_texture_06002170", "mr_i_iris_seg6_texture_06002970",
        "mr_i_iris_seg6_texture_06003170", "mr_i_iris_seg6_texture_06003970", "peach_seg5_texture_05000A28",
        "peach_seg5_texture_05001228", "peach_seg5_texture_05001A28", "peach_seg5_texture_05002228",
        "peach_seg5_texture_05002E28", "peach_seg5_texture_05003628", "peach_seg5_texture_05004028",
        "pebble_seg3_texture_0301C300", "penguin_seg5_texture_05002DE0", "penguin_seg5_texture_050035E0",
        "penguin_seg5_texture_05003DE0", "penguin_seg5_texture_050045E0", "penguin_seg5_texture_05004DE0",
        "penguin_seg5_texture_050055E0", "piranha_plant_seg6_texture_060123F8", "piranha_plant_seg6_texture_06012BF8",
        "piranha_plant_seg6_texture_060133F8", "piranha_plant_seg6_texture_06013BF8", "pokey_seg5_texture_05011750",
        "pokey_seg5_texture_05011F50", "pokey_seg5_texture_05012878", "poundable_pole_seg6_texture_06001050",
        "poundable_pole_seg6_texture_06001850", "scuttlebug_seg6_texture_06010108", "scuttlebug_seg6_texture_06012908",
        "scuttlebug_seg6_texture_06013108", "seaweed_seg6_texture_06007E10", "seaweed_seg6_texture_06008610",
        "seaweed_seg6_texture_06008E10", "seaweed_seg6_texture_06009610", "skeeter_seg6_texture_06000090",
        "snowman_seg5_texture_05008C70", "snowman_seg5_texture_0500B470", "snowman_seg5_texture_0500BC70",
        "snufit_seg6_texture_060070E0", "snufit_seg6_texture_060078E0", "snufit_seg6_texture_060084E0",
        "sparkles_seg4_texture_04027490", "sparkles_seg4_texture_04027C90", "sparkles_seg4_texture_04028490",
        "sparkles_seg4_texture_04028C90", "sparkles_seg4_texture_04029490", "sparkles_seg4_texture_04029C90",
        "spindrift_seg5_texture_050006D0", "spindrift_seg5_texture_05000ED0", "spindrift_seg5_texture_050016D0",
        "spindrift_seg5_texture_05001ED0", "springboard_seg5_texture_05000018", "springboard_seg5_texture_05000818",
        "star_seg3_texture_0302A6F0", "star_seg3_texture_0302AEF0", "sushi_seg5_texture_05008ED0",
        "swoop_seg6_texture_06004270", "swoop_seg6_texture_06004A70", "swoop_seg6_texture_06005270",
        "swoop_seg6_texture_06005A70", "thwomp_seg5_texture_0500A900", "toad_seg6_texture_06005920",
        "toad_seg6_texture_06006120", "treasure_chest_seg6_texture_06013FA8", "treasure_chest_seg6_texture_060147A8",
        "treasure_chest_seg6_texture_06014FA8", "ukiki_seg5_texture_05009BC0", "ukiki_seg5_texture_0500A3C0",
        "unagi_seg5_texture_0500AF20", "unagi_seg5_texture_0500B920", "unagi_seg5_texture_0500C3A0",
        "warp_pipe_seg3_texture_03009168", "water_bubble_seg5_texture_0500FE80", "water_mine_seg6_texture_0600C4F8",
        "whomp_seg6_texture_0601E360", "whomp_seg6_texture_0601EB60", "wiggler_seg5_texture_05007A30",
        "wiggler_seg5_texture_05008230", "wiggler_seg5_texture_05008A30", "wooden_signpost_seg3_texture_0302C9C8",
        "wooden_signpost_seg3_texture_0302D1C8", "yellow_sphere_seg6_texture_0601EB88", "yellow_sphere_seg5_texture_05000040",
        "yoshi_egg_seg5_texture_050057B8", "yoshi_egg_seg5_texture_05005FB8", "yoshi_egg_seg5_texture_050067B8",
        "yoshi_egg_seg5_texture_05006FB8", "yoshi_egg_seg5_texture_050077B8", "yoshi_egg_seg5_texture_05007FB8",
        "yoshi_egg_seg5_texture_050087B8", "yoshi_egg_seg5_texture_05008FB8", "cave_09001000",
        "cave_09002800", "cave_09003000", "cave_09006800",
        "cave_09007000", "cave_09009800", "cave_0900A000",
        "effect_0B000008", "effect_0B000808", "effect_0B001008",
        "effect_0B001808", "effect_0B002020", "effect_0B002820",
        "effect_0B003020", "effect_0B003820", "effect_0B004020",
        "effect_0B004820", "effect_0B005020", "effect_0B005820",
        "effect_0B006048", "fire_09000000", "fire_09000800",
        "fire_09001000", "fire_09001800", "fire_09002000",
        "fire_09002800", "fire_09003000", "fire_09003800",
        "fire_09004000", "fire_09004800", "fire_09005000",
        "fire_09005800", "fire_09006000", "fire_09006800",
        "fire_09007000", "fire_09007800", "fire_09008000",
        "fire_09008800", "fire_09009000", "fire_09009800",
        "fire_0900A000", "fire_0900A800", "fire_0900B000",
        "fire_0900B800", "generic_09000000", "generic_09000800",
        "generic_09001000", "generic_09001800", "generic_09002000",
        "generic_09002800", "generic_09003000", "generic_09003800",
        "generic_09004000", "generic_09004800", "generic_09005000",
        "generic_09005800", "generic_09007000", "generic_09007800",
        "generic_09008000", "generic_09008800", "generic_09009000",
        "generic_09009800", "generic_0900A000", "generic_0900A800",
        "grass_09000000", "grass_09000800", "grass_09001000",
        "grass_09001800", "grass_09002000", "grass_09002800",
        "grass_09003000", "grass_09003800", "grass_09004000",
        "grass_09004800", "grass_09005000", "grass_09005800",
        "grass_09006000", "grass_09006800", "grass_09007000",
        "grass_09007800", "grass_09008000", "grass_09008800",
        "grass_09009000", "grass_09009800", "grass_0900A000",
        "grass_0900A800", "inside_09003000", "inside_09003800",
        "inside_09004000", "inside_09004800", "inside_09005000",
        "inside_09005800", "inside_09008000", "inside_09008800",
        "inside_0900B000", "machine_09000000", "machine_09000800",
        "machine_09001000", "machine_09001800", "machine_09002000",
        "machine_09002800", "machine_09003000", "machine_09003800",
        "machine_09005000", "machine_09005800", "machine_09006000",
        "machine_09006800", "machine_09007000", "machine_09008400",
        "mountain_09000000", "mountain_09002800", "mountain_09003000",
        "mountain_09003800", "mountain_09004000", "mountain_09004800",
        "mountain_09005000", "mountain_09006800", "mountain_09007000",
        "mountain_09007800", "mountain_09008000", "mountain_09009800",
        "mountain_0900A000", "mountain_0900A800", "mountain_0900B000",
        "mountain_0900B800", "mountain_0900C000", "outside_09000000",
        "outside_09000800", "outside_09003000", "outside_09003800",
        "outside_09004000", "outside_09005800", "outside_09006000",
        "outside_09007800", "outside_09008000", "outside_09008800",
        "outside_09009000", "outside_09009800", "outside_0900A000",
        "outside_0900A800", "outside_0900B400", "sky_09000000",
        "sky_09000800", "sky_09001000", "sky_09001800",
        "sky_09003000", "sky_09004800", "sky_09005000",
        "sky_09005800", "sky_09006000", "texture_metal_hole",
        "sky_09007000", "sky_09007800", "sky_09008000",
        "snow_09000000", "snow_09000800", "snow_09002000",
        "snow_09002800", "snow_09003000", "snow_09003800",
        "snow_09004000", "snow_09004800", "snow_09005000",
        "snow_09005800", "snow_09006000", "snow_09006800",
        "snow_09008000", "snow_09008800", "spooky_09000000",
        "spooky_09004800", "spooky_09006000", "spooky_09006800",
        "spooky_09008000", "spooky_09008800", "spooky_0900A000",
        "water_09000000", "water_09005800", "water_09006000",
        "water_09008800", "water_0900A000", "bbh_seg7_texture_07001000",
        "bbh_seg7_texture_07001800", "bitdw_seg7_texture_07000000", "bitdw_seg7_texture_07000800",
        "bitdw_seg7_texture_07001000", "bitdw_seg7_texture_07001800", "bitfs_seg7_texture_07001000",
        "bitfs_seg7_texture_07001800", "bits_seg7_texture_07002000", "bob_seg7_texture_07000000",
        "bob_seg7_texture_07000800", "bob_seg7_texture_07001000", "bob_seg7_texture_07001800",
        "bob_seg7_texture_07002000", "bowser_1_seg7_texture_07001000", "bowser_1_seg7_texture_07001800",
        "bowser_2_seg7_texture_07000000", "bowser_3_seg7_texture_07000000", "bowser_3_seg7_texture_07000800",
        "inside_castle_seg7_texture_07000800", "inside_castle_seg7_texture_07003000", "inside_castle_seg7_texture_07005800",
        "inside_castle_seg7_texture_07006000", "inside_castle_seg7_texture_07006800", "inside_castle_seg7_texture_07007000",
        "inside_castle_seg7_texture_07007800", "inside_castle_seg7_texture_07008000", "inside_castle_seg7_texture_07008800",
        "inside_castle_seg7_texture_07009000", "inside_castle_seg7_texture_07009800", "ccm_seg7_texture_07011958",
        "ccm_seg7_texture_07000000", "ccm_seg7_texture_07000900", "ccm_seg7_texture_07001100",
        "ccm_seg7_texture_07001900", "ccm_seg7_texture_07002100", "ccm_seg7_texture_07002900",
        "ccm_seg7_texture_07003100", "ccm_seg7_texture_07004300", "ccm_seg7_texture_07004B00",
        "cotmc_seg7_texture_07001000", "cotmc_seg7_texture_07001800", "cotmc_seg7_texture_07002000",
        "ddd_seg7_texture_07001000", "ddd_seg7_texture_07001800", "ddd_seg7_texture_07003000",
        "hmc_seg7_texture_07024CE0", "hmc_seg7_texture_07003000", "hmc_seg7_texture_07003800",
        "hmc_seg7_texture_07004000", "jrb_seg7_texture_07000000", "jrb_seg7_texture_07001800",
        "jrb_seg7_texture_07002000", "lll_seg7_texture_07000000", "lll_seg7_texture_07000800",
        "lll_seg7_texture_07001000", "lll_seg7_texture_07001800", "lll_seg7_texture_07002000",
        "lll_seg7_texture_07002800", "lll_seg7_texture_07003000", "lll_seg7_texture_07003800",
        "lll_seg7_texture_07004000", "lll_seg7_texture_07004800", "lll_seg7_texture_07005000",
        "lll_seg7_texture_07005800", "lll_seg7_texture_07006000", "lll_seg7_texture_07006800",
        "lll_seg7_texture_07007000", "lll_seg7_texture_07007800", "lll_seg7_texture_07008000",
        "lll_seg7_texture_07008800", "lll_seg7_texture_07009000", "lll_seg7_texture_07009800",
        "lll_seg7_texture_0700A000", "lll_seg7_texture_0700A800", "lll_seg7_texture_0700B000",
        "lll_seg7_texture_0700B800", "lll_seg7_texture_0700C000", "lll_seg7_texture_0700C800",
        "lll_seg7_texture_0700D400", "lll_seg7_texture_0700DC00", "lll_seg7_texture_0700E400",
        "lll_seg7_texture_0700EC00", "pss_seg7_texture_07000000", "pss_seg7_texture_07001000",
        "texture_quarter_flying_carpet", "rr_seg7_texture_07001800", "sl_seg7_texture_07000000",
        "sl_seg7_texture_07000800", "sl_seg7_texture_07001000", "sl_seg7_texture_07001800",
        "sl_seg7_texture_07002000", "ssl_quicksand", "ssl_seg7_texture_07000000",
        "ssl_pyramid_sand", "ssl_seg7_texture_07001800", "ssl_seg7_texture_07002000",
        "ssl_seg7_texture_07003800", "ssl_seg7_texture_0700BFA8", "thi_seg7_texture_07000000",
        "thi_seg7_texture_07000800", "totwc_seg7_texture_07001000", "totwc_seg7_texture_07001800",
        "ttc_yellow_triangle", "ttc_seg7_texture_07000000", "ttm_seg7_texture_0702AD30",
        "ttm_seg7_texture_07000800", "ttm_seg7_texture_07001000", "ttm_seg7_texture_07001800",
        "ttm_seg7_texture_07002000", "ttm_seg7_texture_07002800", "vcutm_seg7_texture_07000000",
        "vcutm_seg7_texture_07002800", "wdw_seg7_texture_07000000", "wdw_seg7_texture_07000800",
        "wdw_seg7_texture_07001000", "wdw_seg7_texture_07001800", "wdw_seg7_texture_07002000",
        "wf_seg7_texture_07000000", "wf_seg7_texture_07000800", "wf_seg7_texture_07001000",
        "wf_seg7_texture_07001800", "wf_seg7_texture_07002000", "wmotr_seg7_texture_07000000",
        "wmotr_seg7_texture_07000C00", "mario_texture_yellow_button", "mario_texture_m_logo",
        "mario_texture_m_blend", "mario_texture_m_cap", "mario_texture_hair_sideburn",
        "mario_texture_add_sideburn", "mario_texture_skin_sideburn", "mario_texture_mustache",
        "mario_texture_eyes_front", "mario_texture_eyes_half_closed", "mario_texture_eyes_closed",
        "mario_texture_eyes_right", "mario_texture_eyes_left", "mario_texture_eyes_up",
        "mario_texture_eyes_down", "mario_texture_eyes_dead", "mario_cap_seg3_texture_0301DF50",
        "luigi_texture_l_logo", "luigi_texture_l_blend", "luigi_texture_l_cap",
        "luigi_texture_hair_sideburn", "luigi_texture_add_sideburn", "luigi_texture_skin_sideburn",
        "luigi_texture_mustache", "wario_texture_white_button", "wario_texture_w_logo",
        "wario_texture_w_blend", "wario_texture_w_cap", "wario_texture_hair_sideburn",
        "wario_texture_add_sideburn", "wario_texture_skin_sideburn", "waluigi_texture_r_logo",
        "waluigi_texture_r_blend", "waluigi_texture_r_cap", "waluigi_texture_hair_sideburn",
        "waluigi_texture_add_sideburn", "waluigi_texture_skin_sideburn", "water_skybox_texture_00000",
        "water_skybox_texture_00001", "water_skybox_texture_00002", "water_skybox_texture_00003",
        "water_skybox_texture_00004", "water_skybox_texture_00005", "water_skybox_texture_00006",
        "water_skybox_texture_00007", "water_skybox_texture_00008", "water_skybox_texture_00009",
        "water_skybox_texture_0000A", "water_skybox_texture_0000B", "water_skybox_texture_0000C",
        "water_skybox_texture_0000D", "water_skybox_texture_0000E", "water_skybox_texture_0000F",
        "water_skybox_texture_00010", "water_skybox_texture_00011", "water_skybox_texture_00012",
        "water_skybox_texture_00013", "water_skybox_texture_00014", "water_skybox_texture_00015",
        "water_skybox_texture_00016", "water_skybox_texture_00017", "water_skybox_texture_00018",
        "water_skybox_texture_00019", "water_skybox_texture_0001A", "water_skybox_texture_0001B",
        "water_skybox_texture_0001C", "water_skybox_texture_0001D", "water_skybox_texture_0001E",
        "water_skybox_texture_0001F", "water_skybox_texture_00020", "water_skybox_texture_00021",
        "water_skybox_texture_00022", "water_skybox_texture_00023", "water_skybox_texture_00024",
        "water_skybox_texture_00025", "water_skybox_texture_00026", "water_skybox_texture_00027",
        "water_skybox_texture_00028", "water_skybox_texture_00029", "water_skybox_texture_0002A",
        "water_skybox_texture_0002B", "water_skybox_texture_0002C", "water_skybox_texture_0002D",
        "water_skybox_texture_0002E", "water_skybox_texture_0002F", "water_skybox_texture_00030",
        "water_skybox_texture_00031", "water_skybox_texture_00032", "water_skybox_texture_00033",
        "water_skybox_texture_00034", "water_skybox_texture_00035", "water_skybox_texture_00036",
        "water_skybox_texture_00037", "water_skybox_texture_00038", "water_skybox_texture_00039",
        "water_skybox_texture_0003A", "water_skybox_texture_0003B", "water_skybox_texture_0003C",
        "water_skybox_texture_0003D", "water_skybox_texture_0003E", "water_skybox_texture_0003F",
        "bitfs_skybox_texture_00000", "bitfs_skybox_texture_00001", "bitfs_skybox_texture_00002",
        "bitfs_skybox_texture_00003", "bitfs_skybox_texture_00004", "bitfs_skybox_texture_00005",
        "bitfs_skybox_texture_00006", "bitfs_skybox_texture_00007", "bitfs_skybox_texture_00008",
        "bitfs_skybox_texture_00009", "bitfs_skybox_texture_0000A", "bitfs_skybox_texture_0000B",
        "bitfs_skybox_texture_0000C", "bitfs_skybox_texture_0000D", "bitfs_skybox_texture_0000E",
        "bitfs_skybox_texture_0000F", "bitfs_skybox_texture_00010", "bitfs_skybox_texture_00011",
        "bitfs_skybox_texture_00012", "bitfs_skybox_texture_00013", "bitfs_skybox_texture_00014",
        "bitfs_skybox_texture_00015", "bitfs_skybox_texture_00016", "bitfs_skybox_texture_00017",
        "bitfs_skybox_texture_00018", "bitfs_skybox_texture_00019", "bitfs_skybox_texture_0001A",
        "bitfs_skybox_texture_0001B", "bitfs_skybox_texture_0001C", "bitfs_skybox_texture_0001D",
        "bitfs_skybox_texture_0001E", "bitfs_skybox_texture_0001F", "bitfs_skybox_texture_00020",
        "bitfs_skybox_texture_00021", "bitfs_skybox_texture_00022", "bitfs_skybox_texture_00023",
        "bitfs_skybox_texture_00024", "bitfs_skybox_texture_00025", "bitfs_skybox_texture_00026",
        "bitfs_skybox_texture_00027", "bitfs_skybox_texture_00028", "bitfs_skybox_texture_00029",
        "bitfs_skybox_texture_0002A", "bitfs_skybox_texture_0002B", "bitfs_skybox_texture_0002C",
        "bitfs_skybox_texture_0002D", "bitfs_skybox_texture_0002E", "bitfs_skybox_texture_0002F",
        "bitfs_skybox_texture_00030", "wdw_skybox_texture_00000", "wdw_skybox_texture_00001",
        "wdw_skybox_texture_00002", "wdw_skybox_texture_00003", "wdw_skybox_texture_00004",
        "wdw_skybox_texture_00005", "wdw_skybox_texture_00006", "wdw_skybox_texture_00007",
        "wdw_skybox_texture_00008", "wdw_skybox_texture_00009", "wdw_skybox_texture_0000A",
        "wdw_skybox_texture_0000B", "wdw_skybox_texture_0000C", "wdw_skybox_texture_0000D",
        "wdw_skybox_texture_0000E", "wdw_skybox_texture_0000F", "wdw_skybox_texture_00010",
        "wdw_skybox_texture_00011", "wdw_skybox_texture_00012", "wdw_skybox_texture_00013",
        "wdw_skybox_texture_00014", "wdw_skybox_texture_00015", "wdw_skybox_texture_00016",
        "wdw_skybox_texture_00017", "wdw_skybox_texture_00018", "wdw_skybox_texture_00019",
        "wdw_skybox_texture_0001A", "wdw_skybox_texture_0001B", "wdw_skybox_texture_0001C",
        "wdw_skybox_texture_0001D", "wdw_skybox_texture_0001E", "wdw_skybox_texture_0001F",
        "wdw_skybox_texture_00020", "wdw_skybox_texture_00021", "wdw_skybox_texture_00022",
        "wdw_skybox_texture_00023", "wdw_skybox_texture_00024", "wdw_skybox_texture_00025",
        "wdw_skybox_texture_00026", "wdw_skybox_texture_00027", "wdw_skybox_texture_00028",
        "wdw_skybox_texture_00029", "wdw_skybox_texture_0002A", "wdw_skybox_texture_0002B",
        "wdw_skybox_texture_0002C", "wdw_skybox_texture_0002D", "wdw_skybox_texture_0002E",
        "wdw_skybox_texture_0002F", "wdw_skybox_texture_00030", "wdw_skybox_texture_00031",
        "wdw_skybox_texture_00032", "wdw_skybox_texture_00033", "wdw_skybox_texture_00034",
        "wdw_skybox_texture_00035", "wdw_skybox_texture_00036", "wdw_skybox_texture_00037",
        "wdw_skybox_texture_00038", "wdw_skybox_texture_00039", "wdw_skybox_texture_0003A",
        "wdw_skybox_texture_0003B", "wdw_skybox_texture_0003C", "wdw_skybox_texture_0003D",
        "wdw_skybox_texture_0003E", "wdw_skybox_texture_0003F", "cloud_floor_skybox_texture_00000",
        "cloud_floor_skybox_texture_00001", "cloud_floor_skybox_texture_00002", "cloud_floor_skybox_texture_00003",
        "cloud_floor_skybox_texture_00004", "cloud_floor_skybox_texture_00005", "cloud_floor_skybox_texture_00006",
        "cloud_floor_skybox_texture_00007", "cloud_floor_skybox_texture_00008", "cloud_floor_skybox_texture_00009",
        "cloud_floor_skybox_texture_0000A", "cloud_floor_skybox_texture_0000B", "cloud_floor_skybox_texture_0000C",
        "cloud_floor_skybox_texture_0000D", "cloud_floor_skybox_texture_0000E", "cloud_floor_skybox_texture_0000F",
        "cloud_floor_skybox_texture_00010", "cloud_floor_skybox_texture_00011", "cloud_floor_skybox_texture_00012",
        "cloud_floor_skybox_texture_00013", "cloud_floor_skybox_texture_00014", "cloud_floor_skybox_texture_00015",
        "cloud_floor_skybox_texture_00016", "cloud_floor_skybox_texture_00017", "cloud_floor_skybox_texture_00018",
        "cloud_floor_skybox_texture_00019", "cloud_floor_skybox_texture_0001A", "cloud_floor_skybox_texture_0001B",
        "cloud_floor_skybox_texture_0001C", "cloud_floor_skybox_texture_0001D", "cloud_floor_skybox_texture_0001E",
        "cloud_floor_skybox_texture_0001F", "cloud_floor_skybox_texture_00020", "cloud_floor_skybox_texture_00021",
        "cloud_floor_skybox_texture_00022", "cloud_floor_skybox_texture_00023", "cloud_floor_skybox_texture_00024",
        "cloud_floor_skybox_texture_00025", "cloud_floor_skybox_texture_00026", "cloud_floor_skybox_texture_00027",
        "cloud_floor_skybox_texture_00028", "cloud_floor_skybox_texture_00029", "cloud_floor_skybox_texture_0002A",
        "cloud_floor_skybox_texture_0002B", "cloud_floor_skybox_texture_0002C", "cloud_floor_skybox_texture_0002D",
        "cloud_floor_skybox_texture_0002E", "cloud_floor_skybox_texture_0002F", "cloud_floor_skybox_texture_00030",
        "cloud_floor_skybox_texture_00031", "cloud_floor_skybox_texture_00032", "cloud_floor_skybox_texture_00033",
        "cloud_floor_skybox_texture_00034", "cloud_floor_skybox_texture_00035", "cloud_floor_skybox_texture_00036",
        "cloud_floor_skybox_texture_00037", "cloud_floor_skybox_texture_00038", "cloud_floor_skybox_texture_00039",
        "cloud_floor_skybox_texture_0003A", "cloud_floor_skybox_texture_0003B", "cloud_floor_skybox_texture_0003C",
        "cloud_floor_skybox_texture_0003D", "cloud_floor_skybox_texture_0003E", "cloud_floor_skybox_texture_0003F",
        "ccm_skybox_texture_00000", "ccm_skybox_texture_00001", "ccm_skybox_texture_00002",
        "ccm_skybox_texture_00003", "ccm_skybox_texture_00004", "ccm_skybox_texture_00005",
        "ccm_skybox_texture_00006", "ccm_skybox_texture_00007", "ccm_skybox_texture_00008",
        "ccm_skybox_texture_00009", "ccm_skybox_texture_0000A", "ccm_skybox_texture_0000B",
        "ccm_skybox_texture_0000C", "ccm_skybox_texture_0000D", "ccm_skybox_texture_0000E",
        "ccm_skybox_texture_0000F", "ccm_skybox_texture_00010", "ccm_skybox_texture_00011",
        "ccm_skybox_texture_00012", "ccm_skybox_texture_00013", "ccm_skybox_texture_00014",
        "ccm_skybox_texture_00015", "ccm_skybox_texture_00016", "ccm_skybox_texture_00017",
        "ccm_skybox_texture_00018", "ccm_skybox_texture_00019", "ccm_skybox_texture_0001A",
        "ccm_skybox_texture_0001B", "ccm_skybox_texture_0001C", "ccm_skybox_texture_0001D",
        "ccm_skybox_texture_0001E", "ccm_skybox_texture_0001F", "ccm_skybox_texture_00020",
        "ccm_skybox_texture_00021", "ccm_skybox_texture_00022", "ccm_skybox_texture_00023",
        "ccm_skybox_texture_00024", "ccm_skybox_texture_00025", "ccm_skybox_texture_00026",
        "ccm_skybox_texture_00027", "ccm_skybox_texture_00028", "ccm_skybox_texture_00029",
        "ccm_skybox_texture_0002A", "ccm_skybox_texture_0002B", "ccm_skybox_texture_0002C",
        "ccm_skybox_texture_0002D", "ccm_skybox_texture_0002E", "ccm_skybox_texture_0002F",
        "ccm_skybox_texture_00030", "ccm_skybox_texture_00031", "ccm_skybox_texture_00032",
        "ccm_skybox_texture_00033", "ccm_skybox_texture_00034", "ccm_skybox_texture_00035",
        "ccm_skybox_texture_00036", "ccm_skybox_texture_00037", "ccm_skybox_texture_00038",
        "ccm_skybox_texture_00039", "ccm_skybox_texture_0003A", "ccm_skybox_texture_0003B",
        "ccm_skybox_texture_0003C", "ccm_skybox_texture_0003D", "ccm_skybox_texture_0003E",
        "ccm_skybox_texture_0003F", "ssl_skybox_texture_00000", "ssl_skybox_texture_00001",
        "ssl_skybox_texture_00002", "ssl_skybox_texture_00003", "ssl_skybox_texture_00004",
        "ssl_skybox_texture_00005", "ssl_skybox_texture_00006", "ssl_skybox_texture_00007",
        "ssl_skybox_texture_00008", "ssl_skybox_texture_00009", "ssl_skybox_texture_0000A",
        "ssl_skybox_texture_0000B", "ssl_skybox_texture_0000C", "ssl_skybox_texture_0000D",
        "ssl_skybox_texture_0000E", "ssl_skybox_texture_0000F", "ssl_skybox_texture_00010",
        "ssl_skybox_texture_00011", "ssl_skybox_texture_00012", "ssl_skybox_texture_00013",
        "ssl_skybox_texture_00014", "ssl_skybox_texture_00015", "ssl_skybox_texture_00016",
        "ssl_skybox_texture_00017", "ssl_skybox_texture_00018", "ssl_skybox_texture_00019",
        "ssl_skybox_texture_0001A", "ssl_skybox_texture_0001B", "ssl_skybox_texture_0001C",
        "ssl_skybox_texture_0001D", "ssl_skybox_texture_0001E", "ssl_skybox_texture_0001F",
        "ssl_skybox_texture_00020", "ssl_skybox_texture_00021", "ssl_skybox_texture_00022",
        "ssl_skybox_texture_00023", "ssl_skybox_texture_00024", "ssl_skybox_texture_00025",
        "ssl_skybox_texture_00026", "ssl_skybox_texture_00027", "ssl_skybox_texture_00028",
        "ssl_skybox_texture_00029", "ssl_skybox_texture_0002A", "ssl_skybox_texture_0002B",
        "ssl_skybox_texture_0002C", "ssl_skybox_texture_0002D", "ssl_skybox_texture_0002E",
        "ssl_skybox_texture_0002F", "ssl_skybox_texture_00030", "ssl_skybox_texture_00031",
        "ssl_skybox_texture_00032", "ssl_skybox_texture_00033", "ssl_skybox_texture_00034",
        "ssl_skybox_texture_00035", "ssl_skybox_texture_00036", "ssl_skybox_texture_00037",
        "ssl_skybox_texture_00038", "ssl_skybox_texture_00039", "ssl_skybox_texture_0003A",
        "ssl_skybox_texture_0003B", "ssl_skybox_texture_0003C", "ssl_skybox_texture_0003D",
        "ssl_skybox_texture_0003E", "ssl_skybox_texture_0003F", "bbh_skybox_texture_00000",
        "bbh_skybox_texture_00001", "bbh_skybox_texture_00002", "bbh_skybox_texture_00003",
        "bbh_skybox_texture_00004", "bbh_skybox_texture_00005", "bbh_skybox_texture_00006",
        "bbh_skybox_texture_00007", "bbh_skybox_texture_00008", "bbh_skybox_texture_00009",
        "bbh_skybox_texture_0000A", "bbh_skybox_texture_0000B", "bbh_skybox_texture_0000C",
        "bbh_skybox_texture_0000D", "bbh_skybox_texture_0000E", "bbh_skybox_texture_0000F",
        "bbh_skybox_texture_00010", "bbh_skybox_texture_00011", "bbh_skybox_texture_00012",
        "bbh_skybox_texture_00013", "bbh_skybox_texture_00014", "bbh_skybox_texture_00015",
        "bbh_skybox_texture_00016", "bbh_skybox_texture_00017", "bbh_skybox_texture_00018",
        "bbh_skybox_texture_00019", "bbh_skybox_texture_0001A", "bbh_skybox_texture_0001B",
        "bbh_skybox_texture_0001C", "bbh_skybox_texture_0001D", "bbh_skybox_texture_0001E",
        "bbh_skybox_texture_0001F", "bbh_skybox_texture_00020", "bbh_skybox_texture_00021",
        "bbh_skybox_texture_00022", "bbh_skybox_texture_00023", "bbh_skybox_texture_00024",
        "bbh_skybox_texture_00025", "bbh_skybox_texture_00026", "bbh_skybox_texture_00027",
        "bbh_skybox_texture_00028", "bitdw_skybox_texture_00000", "bitdw_skybox_texture_00001",
        "bitdw_skybox_texture_00002", "bitdw_skybox_texture_00003", "bitdw_skybox_texture_00004",
        "bitdw_skybox_texture_00005", "bitdw_skybox_texture_00006", "bitdw_skybox_texture_00007",
        "bitdw_skybox_texture_00008", "bitdw_skybox_texture_00009", "bitdw_skybox_texture_0000A",
        "bitdw_skybox_texture_0000B", "bitdw_skybox_texture_0000C", "bitdw_skybox_texture_0000D",
        "bitdw_skybox_texture_0000E", "bitdw_skybox_texture_0000F", "bitdw_skybox_texture_00010",
        "bitdw_skybox_texture_00011", "bitdw_skybox_texture_00012", "bitdw_skybox_texture_00013",
        "bitdw_skybox_texture_00014", "bitdw_skybox_texture_00015", "bitdw_skybox_texture_00016",
        "bitdw_skybox_texture_00017", "bitdw_skybox_texture_00018", "bitdw_skybox_texture_00019",
        "bitdw_skybox_texture_0001A", "bitdw_skybox_texture_0001B", "bitdw_skybox_texture_0001C",
        "bitdw_skybox_texture_0001D", "bitdw_skybox_texture_0001E", "bitdw_skybox_texture_0001F",
        "bitdw_skybox_texture_00020", "bitdw_skybox_texture_00021", "bitdw_skybox_texture_00022",
        "bitdw_skybox_texture_00023", "bitdw_skybox_texture_00024", "bitdw_skybox_texture_00025",
        "bitdw_skybox_texture_00026", "bitdw_skybox_texture_00027", "bitdw_skybox_texture_00028",
        "bitdw_skybox_texture_00029", "bitdw_skybox_texture_0002A", "bitdw_skybox_texture_0002B",
        "bitdw_skybox_texture_0002C", "bitdw_skybox_texture_0002D", "bitdw_skybox_texture_0002E",
        "bitdw_skybox_texture_0002F", "bitdw_skybox_texture_00030", "bitdw_skybox_texture_00031",
        "bitdw_skybox_texture_00032", "bitdw_skybox_texture_00033", "bitdw_skybox_texture_00034",
        "bitdw_skybox_texture_00035", "bitdw_skybox_texture_00036", "bitdw_skybox_texture_00037",
        "bitdw_skybox_texture_00038", "bitdw_skybox_texture_00039", "bitdw_skybox_texture_0003A",
        "bitdw_skybox_texture_0003B", "bitdw_skybox_texture_0003C", "bitdw_skybox_texture_0003D",
        "bitdw_skybox_texture_0003E", "bitdw_skybox_texture_0003F", "clouds_skybox_texture_00000",
        "clouds_skybox_texture_00001", "clouds_skybox_texture_00002", "clouds_skybox_texture_00003",
        "clouds_skybox_texture_00004", "clouds_skybox_texture_00005", "clouds_skybox_texture_00006",
        "clouds_skybox_texture_00007", "clouds_skybox_texture_00008", "clouds_skybox_texture_00009",
        "clouds_skybox_texture_0000A", "clouds_skybox_texture_0000B", "clouds_skybox_texture_0000C",
        "clouds_skybox_texture_0000D", "clouds_skybox_texture_0000E", "clouds_skybox_texture_0000F",
        "clouds_skybox_texture_00010", "clouds_skybox_texture_00011", "clouds_skybox_texture_00012",
        "clouds_skybox_texture_00013", "clouds_skybox_texture_00014", "clouds_skybox_texture_00015",
        "clouds_skybox_texture_00016", "clouds_skybox_texture_00017", "clouds_skybox_texture_00018",
        "clouds_skybox_texture_00019", "clouds_skybox_texture_0001A", "clouds_skybox_texture_0001B",
        "clouds_skybox_texture_0001C", "clouds_skybox_texture_0001D", "clouds_skybox_texture_0001E",
        "clouds_skybox_texture_0001F", "clouds_skybox_texture_00020", "clouds_skybox_texture_00021",
        "clouds_skybox_texture_00022", "clouds_skybox_texture_00023", "clouds_skybox_texture_00024",
        "clouds_skybox_texture_00025", "clouds_skybox_texture_00026", "clouds_skybox_texture_00027",
        "clouds_skybox_texture_00028", "bits_skybox_texture_00000", "bits_skybox_texture_00001",
        "bits_skybox_texture_00002", "bits_skybox_texture_00003", "bits_skybox_texture_00004",
        "bits_skybox_texture_00005", "bits_skybox_texture_00006", "bits_skybox_texture_00007",
        "bits_skybox_texture_00008", "bits_skybox_texture_00009", "bits_skybox_texture_0000A",
        "bits_skybox_texture_0000B", "bits_skybox_texture_0000C", "bits_skybox_texture_0000D",
        "bits_skybox_texture_0000E", "bits_skybox_texture_0000F", "bits_skybox_texture_00010",
        "bits_skybox_texture_00011", "bits_skybox_texture_00012", "bits_skybox_texture_00013",
        "bits_skybox_texture_00014", "bits_skybox_texture_00015", "bits_skybox_texture_00016",
        "bits_skybox_texture_00017", "bits_skybox_texture_00018", "bits_skybox_texture_00019",
        "bits_skybox_texture_0001A", "bits_skybox_texture_0001B", "bits_skybox_texture_0001C",
        "bits_skybox_texture_0001D", "bits_skybox_texture_0001E", "bits_skybox_texture_0001F",
        "bits_skybox_texture_00020", "bits_skybox_texture_00021", "bits_skybox_texture_00022",
        "bits_skybox_texture_00023", "bits_skybox_texture_00024", "bits_skybox_texture_00025",
        "bits_skybox_texture_00026", "bits_skybox_texture_00027", "bits_skybox_texture_00028",
        "bits_skybox_texture_00029", "bits_skybox_texture_0002A", "bits_skybox_texture_0002B",
        "bits_skybox_texture_0002C", "bits_skybox_texture_0002D", "bits_skybox_texture_0002E",
        "bits_skybox_texture_0002F", "bits_skybox_texture_00030", "bits_skybox_texture_00031",
        "bits_skybox_texture_00032", "bits_skybox_texture_00033", "bits_skybox_texture_00034",
        "bits_skybox_texture_00035", "bits_skybox_texture_00036", "bits_skybox_texture_00037",
        "bits_skybox_texture_00038", "bits_skybox_texture_00039", "bits_skybox_texture_0003A",
        "bits_skybox_texture_0003B", "bits_skybox_texture_0003C", "bits_skybox_texture_0003D",
        "bits_skybox_texture_0003E", "bits_skybox_texture_0003F",
    } },
    { w = 32, h = 64, names = {
        "bobomb_seg8_texture_0801DA60", "bobomb_seg8_texture_0801EA60", "bobomb_seg8_texture_0801FA60",
        "bobomb_seg8_texture_08020A60", "bomb_seg6_texture_06057AC0", "bomb_seg6_texture_06058AC0",
        "bowser_seg6_texture_06024438", "bowser_seg6_texture_06028C38", "bowser_seg6_texture_06029C38",
        "bowser_seg6_texture_0602AC38", "bowser_seg6_texture_0602BC38", "bowser_key_left_texture",
        "bowser_key_right_texture", "bully_seg5_texture_05000468", "bully_seg5_texture_05001468",
        "butterfly_seg3_texture_030043A8", "chilly_chief_seg6_texture_06000060", "chilly_chief_seg6_texture_06001060",
        "chuckya_seg8_texture_08006778", "chuckya_seg8_texture_08007F78", "chuckya_seg8_texture_08008F78",
        "door_seg3_texture_03009D10", "door_seg3_texture_0300AD10", "door_seg3_texture_0300BD10",
        "door_seg3_texture_0300D510", "door_seg3_texture_0300ED10", "door_seg3_texture_03010510",
        "dorrie_seg6_texture_06009DA0", "exclamation_box_seg8_texture_08013628", "exclamation_box_seg8_texture_08016628",
        "king_bobomb_seg5_texture_05000078", "king_bobomb_seg5_texture_05001078", "king_bobomb_seg5_texture_05004878",
        "king_bobomb_seg5_texture_05008478", "king_bobomb_seg5_texture_05009478", "klepto_seg5_texture_05001008",
        "manta_seg5_texture_05001FA0", "metal_box_seg8_texture_08023998", "mr_i_eyeball_seg6_texture_06000080",
        "mr_i_eyeball_seg6_texture_06001080", "mushroom_1up_seg3_texture_03029628", "piranha_plant_seg6_texture_060113F8",
        "piranha_plant_seg6_texture_060143F8", "scuttlebug_seg6_texture_06010908", "scuttlebug_seg6_texture_06011908",
        "snowman_seg5_texture_05009470", "snowman_seg5_texture_0500A470", "thwomp_seg5_texture_05009900",
        "tree_seg3_texture_0302DE28", "tree_seg3_texture_0302EE28", "tree_seg3_texture_0302FF60",
        "tree_seg3_texture_03031048", "tree_seg3_texture_03032218", "warp_pipe_seg3_texture_03007E40",
        "water_mine_seg6_texture_0600A4F8", "water_mine_seg6_texture_0600B4F8", "water_splash_seg4_texture_0402A5C8",
        "water_splash_seg4_texture_0402B5C8", "water_splash_seg4_texture_0402C5C8", "water_splash_seg4_texture_0402D5C8",
        "water_splash_seg4_texture_0402E5C8", "water_splash_seg4_texture_0402F5C8", "water_splash_seg4_texture_040305C8",
        "water_splash_seg4_texture_040315C8", "whomp_seg6_texture_0601C360", "whomp_seg6_texture_0601D360",
        "wiggler_seg5_texture_05005A30", "wiggler_seg5_texture_05006A30", "wiggler_seg5_texture_05009230",
        "wiggler_seg5_texture_0500A230", "cave_09000000", "cave_09001800",
        "cave_09003800", "cave_09005800", "cave_09007800",
        "cave_09008800", "cave_0900A800", "generic_09006000",
        "inside_09002000", "inside_09006000", "inside_09007000",
        "inside_09009000", "inside_0900A000", "machine_09004000",
        "mountain_09001800", "mountain_09005800", "outside_09002000",
        "outside_09004800", "sky_09002000", "snow_09001000",
        "spooky_09000800", "spooky_09001800", "spooky_09002800",
        "spooky_09003800", "spooky_09005000", "bbh_seg7_texture_07000000",
        "bbh_seg7_texture_07002000", "bbh_seg7_texture_07003400", "bitfs_seg7_texture_07000000",
        "bits_seg7_texture_07000000", "bowser_1_seg7_texture_07000000", "bowser_3_seg7_texture_07001000",
        "castle_grounds_seg7_texture_0700C9E8", "castle_grounds_seg7_texture_0700D9E8", "castle_grounds_seg7_texture_07000000",
        "inside_castle_seg7_texture_07002000", "inside_castle_seg7_texture_07003800", "inside_castle_seg7_texture_07004800",
        "ddd_seg7_texture_07000000", "hmc_seg7_texture_07000000", "hmc_seg7_texture_07001000",
        "hmc_seg7_texture_07002000", "hmc_seg7_texture_07004800", "ssl_seg7_texture_07002800",
        "ssl_seg7_texture_0700C7A8", "ssl_seg7_texture_0700D7A8", "ssl_seg7_texture_0700E7A8",
        "totwc_seg7_texture_07000000", "vcutm_seg7_texture_07001800", "mario_texture_wings_half_1",
        "mario_texture_wings_half_2", "mario_texture_metal_wings_half_1_shade", "mario_texture_metal_wings_half_1_light",
        "mario_texture_metal_wings_half_2_shade", "mario_texture_metal_wings_half_2_light", "mario_cap_seg3_texture_0301E750",
        "mario_cap_seg3_texture_0301F750", "mario_cap_seg3_texture_03020750", "mario_cap_seg3_texture_03021750",
        "castle_courtyard_seg7_texture_07000000", "castle_grounds_seg7_texture_07003000",
    } },
    { w = 64, h = 32, names = {
        "boo_seg5_texture_05009B40", "boo_castle_seg6_texture_06015670", "bowser_seg6_texture_0601FC38",
        "bowser_seg6_texture_06021438", "bowser_seg6_texture_06022C38", "bowser_seg6_texture_06026438",
        "bowser_seg6_texture_06027438", "bowser_seg6_texture_0602CC38", "bowser_seg6_texture_0602DC38",
        "bowser_seg6_texture_0602EC38", "bowser_seg6_texture_0602FC38", "bowser_seg6_texture_06030C38",
        "bowser_seg6_texture_06031C38", "bowser_seg6_texture_06032C38", "bowser_seg6_texture_06033C38",
        "bowser_seg6_texture_06034C38", "bowser_seg6_texture_06035C38", "bowser_seg6_texture_06036C38",
        "bowser_seg6_texture_06037C38", "bub_seg6_texture_0600F2A8", "bub_seg6_texture_060102A8",
        "bubba_seg5_texture_05000408", "bullet_bill_seg5_texture_0500BAA8", "bullet_bill_seg5_texture_0500CAA8",
        "exclamation_box_seg8_texture_08014E28", "exclamation_box_seg8_texture_08017E28", "flyguy_seg8_texture_0800E088",
        "heave_ho_seg5_texture_0500F9C8", "klepto_seg5_texture_05002008", "koopa_seg6_texture_06005E48",
        "lakitu_seg6_texture_06000800", "lakitu_seg6_texture_06001800", "lakitu_enemy_seg5_texture_0500F4E0",
        "lakitu_enemy_seg5_texture_050104E0", "manta_seg5_texture_050037A0", "moneybag_seg6_texture_060039B0",
        "treasure_chest_seg6_texture_060157A8", "ukiki_seg5_texture_05007BC0", "ukiki_seg5_texture_05008BC0",
        "water_ring_seg6_texture_06012380", "cave_09004800", "inside_09000000",
        "inside_09001000", "inside_0900B800", "mountain_09000800",
        "mountain_09008800", "outside_09001000", "outside_09006800",
        "sky_09003800", "snow_09007000", "spooky_09007000",
        "spooky_09009000", "water_09000800", "water_09001800",
        "water_09002800", "water_09003800", "water_09004800",
        "water_09006800", "water_09007800", "water_09009000",
        "water_0900A800", "water_0900B800", "bits_seg7_texture_07001000",
        "castle_grounds_seg7_texture_07001000", "castle_grounds_seg7_texture_07002000", "cotmc_seg7_texture_07000000",
        "ddd_seg7_texture_07002000", "jrb_seg7_texture_07000800", "rr_seg7_texture_07000800",
        "ttm_seg7_texture_07003000", "ttm_seg7_texture_07004000", "vcutm_seg7_texture_07000800",
        "mario_texture_metal_shade", "mario_texture_metal_light", "mario_cap_seg3_texture_0301CF50",
        "wario_texture_mouth", "wario_texture_mouth_dead", "wario_texture_eyes_front",
        "wario_texture_eyes_half_closed", "wario_texture_eyes_closed", "wario_texture_eyes_right",
        "wario_texture_eyes_left", "wario_texture_eyes_up", "wario_texture_eyes_down",
        "wario_texture_eyes_dead", "waluigi_texture_mouth", "waluigi_texture_mouth_dead",
        "waluigi_texture_eyes_front", "waluigi_texture_eyes_half_closed", "waluigi_texture_eyes_closed",
        "waluigi_texture_eyes_right", "waluigi_texture_eyes_left", "waluigi_texture_eyes_up",
        "waluigi_texture_eyes_down", "waluigi_texture_eyes_dead", "cake_end_texture_eu_35",
        "cake_end_texture_eu_36", "cake_end_texture_eu_37", "cake_end_texture_eu_38",
        "cake_end_texture_eu_39", "cake_end_texture_eu_40",
    } },
}
do
    local have = {}
    for _, target in ipairs(TARGETS) do have[target.name] = true end
    for _, class in ipairs(EVERY_TARGET) do
        for _, name in ipairs(class.names) do
            if not have[name] then
                have[name] = true
                table.insert(TARGETS, { name = name, w = class.w, h = class.h,
                    cite = "data/dynos_mgr_builtin_tex.cpp" })
            end
        end
    end
end

function texshuffle.target_count()
    return #TARGETS
end

local TARGETS_BY_CLASS = {}
for _, target in ipairs(TARGETS) do
    local class = target.w .. "x" .. target.h
    TARGETS_BY_CLASS[class] = TARGETS_BY_CLASS[class] or {}
    table.insert(TARGETS_BY_CLASS[class], target.name)
end

local REPLACEMENTS = {
    ["32x32"] = {
        "of_shf_adobe", "of_shf_basaltrough", "of_shf_brbrown", "of_shf_brred", "of_shf_bryellow",
        "of_shf_castlegrey", "of_shf_castlesand", "of_shf_cobble", "of_shf_copperpatina",
        "of_shf_cuttile", "of_shf_dirtbrown", "of_shf_flagslate", "of_shf_grasslush",
        "of_shf_grassmeadow", "of_shf_gravel", "of_shf_hexpave", "of_shf_icesmooth",
        "of_shf_marblerose", "of_shf_marblewhite", "of_shf_poolblue", "of_shf_rfclay",
        "of_shf_rfslate", "of_shf_sandbeach", "of_shf_sanddune", "of_shf_sandstone",
        "of_shf_sbblue", "of_shf_sbgrey", "of_shf_sblarge", "of_shf_setts", "of_shf_snowfresh",
        "of_shf_steelplate", "of_shf_terracotta", "of_shf_wdbirch", "of_shf_wdoak",
        "of_shf_wdpine", "of_shf_wdvertblue",
    },
    ["32x64"] = {
        "of_shf_brclinkert", "of_shf_castlebluet", "of_shf_icebrickt", "of_shf_rockgreyt",
        "of_shf_sandstonelayeredt", "of_shf_wdvertredt",
    },
    ["64x32"] = {
        "of_shf_brstackw", "of_shf_cobblewarmw", "of_shf_rfshinglew", "of_shf_sbsmallw",
        "of_shf_steelcorrugatedw", "of_shf_wdvertw",
    },
}

local function step_of(state)
    return (1103515245 * state + 12345) % 2147483648
end

local function stream_for(seed, key)
    local mixed = 0
    for index = 1, #key do
        mixed = (mixed * 131 + string.byte(key, index)) % 2147483648
    end
    local state = (seed * 1103515 + mixed) % 2147483648
    state = step_of(state)

    return function(bound)
        if bound == nil or bound < 1 then return 1 end
        state = step_of(state)
        return (state // 32768) % bound + 1
    end
end

function texshuffle.pool_size(class)
    local pool = REPLACEMENTS[class]
    if pool == nil then return 0 end
    return #pool
end

function texshuffle.mapping(seed)
    local map = {}
    if type(seed) ~= "number" or seed <= 0 then return map end
    seed = math.floor(seed)
    for class, targets in pairs(TARGETS_BY_CLASS) do
        local pool = REPLACEMENTS[class]
        local size = texshuffle.pool_size(class)
        if size > 0 then
            local draw = stream_for(seed, class)
            local deck, left = {}, 0
            for _, name in ipairs(targets) do
                if left == 0 then
                    for index = 1, size do deck[index] = pool[index] end
                    for index = #deck, 2, -1 do
                        local other = draw(index)
                        deck[index], deck[other] = deck[other], deck[index]
                    end
                    left = #deck
                end
                map[name] = deck[left]
                left = left - 1
            end
        end
    end
    return map
end

texshuffle.SWAP_KEY = "texswap"
local SWAP_KINDS = {
    bbh_seg7_texture_07000000 = { "wood", "32x64" },
    bbh_seg7_texture_07001800 = { "ironfence", "32x32" },
    bitdw_seg7_texture_07001000 = { "wood", "32x32" },
    bitdw_seg7_texture_07001800 = { "ice", "32x32" },
    bitfs_seg7_texture_07000000 = { "mesh", "64x32" },
    bitfs_seg7_texture_07001000 = { "tile", "32x32" },
    bob_seg7_texture_07000000 = { "postchain", "32x32" },
    bob_seg7_texture_07001000 = { "grass", "32x32" },
    bowser_1_seg7_texture_07001000 = { "stone", "32x32" },
    bowser_1_seg7_texture_07001800 = { "tile", "32x32" },
    bowser_2_seg7_texture_07000000 = { "lava", "32x32" },
    bowser_3_seg7_texture_07000000 = { "tile", "32x32" },
    castle_courtyard_seg7_texture_07000000 = { "grass", "32x64" },
    castle_grounds_seg7_texture_07000000 = { "peg", "32x64" },
    castle_grounds_seg7_texture_07003000 = { "grass", "32x64" },
    cave_09000000 = { "stone", "32x64" },
    cave_09001000 = { "diamond", "32x32" },
    cave_09001800 = { "dirt", "32x64" },
    cave_09003800 = { "stone", "32x64" },
    cave_09004800 = { "stone", "64x32" },
    cave_09005800 = { "stone", "32x64" },
    cave_09006800 = { "stone", "32x32" },
    cave_09007800 = { "brick", "32x64" },
    cave_09008800 = { "stone", "32x64" },
    cave_09009800 = { "sand", "32x32" },
    ccm_seg7_texture_07003100 = { "ice", "32x32" },
    ccm_seg7_texture_07004B00 = { "tile", "32x32" },
    ccm_seg7_texture_07011958 = { "ice", "32x32" },
    cotmc_seg7_texture_07000000 = { "grass", "64x32" },
    cotmc_seg7_texture_07001000 = { "stone", "32x32" },
    cotmc_seg7_texture_07002000 = { "stone", "32x32" },
    ddd_seg7_texture_07001000 = { "diamond", "32x32" },
    ddd_seg7_texture_07001800 = { "metal", "32x32" },
    fire_09000000 = { "grate", "32x32" },
    fire_09000800 = { "grate", "32x32" },
    fire_09001000 = { "stone", "32x32" },
    fire_09001800 = { "stone", "32x32" },
    fire_09002000 = { "stone", "32x32" },
    fire_09002800 = { "stone", "32x32" },
    fire_09003000 = { "stone", "32x32" },
    fire_09003800 = { "tile", "32x32" },
    fire_09004000 = { "metal", "32x32" },
    fire_09004800 = { "brick", "32x32" },
    fire_09005000 = { "stone", "32x32" },
    fire_09005800 = { "stone", "32x32" },
    fire_09006000 = { "brick", "32x32" },
    fire_09007000 = { "tile", "32x32" },
    fire_09008000 = { "wood", "32x32" },
    fire_09009000 = { "lava", "32x32" },
    fire_09009800 = { "lava", "32x32" },
    fire_0900A000 = { "metal", "32x32" },
    fire_0900A800 = { "stone", "32x32" },
    fire_0900B000 = { "wood", "32x32" },
    generic_09000000 = { "crossjoint", "32x32" },
    generic_09000800 = { "stone", "32x32" },
    generic_09001000 = { "tile", "32x32" },
    generic_09001800 = { "stone", "32x32" },
    generic_09002000 = { "stone", "32x32" },
    generic_09002800 = { "sand", "32x32" },
    generic_09003000 = { "stone", "32x32" },
    generic_09003800 = { "stone", "32x32" },
    generic_09004000 = { "grasscliff", "32x32" },
    generic_09004800 = { "tile", "32x32" },
    generic_09005000 = { "stone", "32x32" },
    generic_09005800 = { "grass", "32x32" },
    generic_09006000 = { "wood", "32x64" },
    generic_09007800 = { "wood", "32x32" },
    generic_09008000 = { "sand", "32x32" },
    generic_09008800 = { "poles", "32x32" },
    generic_09009000 = { "stone", "32x32" },
    generic_09009800 = { "dirt", "32x32" },
    generic_0900A000 = { "dirt", "32x32" },
    generic_0900A800 = { "tile", "32x32" },
    grass_09000000 = { "lattice", "32x32" },
    grass_09000800 = { "brick", "32x32" },
    grass_09001000 = { "brick", "32x32" },
    grass_09001800 = { "stone", "32x32" },
    grass_09002000 = { "grass", "32x32" },
    grass_09003000 = { "stone", "32x32" },
    grass_09003800 = { "stone", "32x32" },
    grass_09004000 = { "tile", "32x32" },
    grass_09004800 = { "dirt", "32x32" },
    grass_09005000 = { "grassedge", "32x32" },
    grass_09005800 = { "grass", "32x32" },
    grass_09006000 = { "windowframe", "32x32" },
    grass_09006800 = { "wood", "32x32" },
    grass_09007000 = { "sand", "32x32" },
    grass_09007800 = { "metal", "32x32" },
    grass_09008000 = { "stone", "32x32" },
    grass_09008800 = { "brick", "32x32" },
    grass_09009000 = { "brick", "32x32" },
    grass_09009800 = { "tile", "32x32" },
    grass_0900A000 = { "fencebeams", "32x32" },
    hmc_seg7_texture_07003000 = { "metal", "32x32" },
    hmc_seg7_texture_07004800 = { "wood", "32x64" },
    inside_09000000 = { "brick", "64x32" },
    inside_09001000 = { "brick", "64x32" },
    inside_09002000 = { "stone", "32x64" },
    inside_09003000 = { "brick", "32x32" },
    inside_09003800 = { "wood", "32x32" },
    inside_09004000 = { "tile", "32x32" },
    inside_09004800 = { "stone", "32x32" },
    inside_09005000 = { "carpet", "32x32" },
    inside_09005800 = { "stone", "32x32" },
    inside_09006000 = { "stone", "32x64" },
    inside_09007000 = { "tile", "32x64" },
    inside_09008800 = { "balustrade", "32x32" },
    inside_09009000 = { "tile", "32x64" },
    inside_0900A000 = { "stone", "32x64" },
    inside_0900B000 = { "tile", "32x32" },
    inside_0900B800 = { "brick", "64x32" },
    inside_castle_seg7_texture_07005800 = { "tile", "32x32" },
    jrb_seg7_texture_07000000 = { "diamond", "32x32" },
    jrb_seg7_texture_07000800 = { "stone", "64x32" },
    jrb_seg7_texture_07002000 = { "wood", "32x32" },
    lll_seg7_texture_07000000 = { "wood", "32x32" },
    lll_seg7_texture_07000800 = { "brick", "32x32" },
    lll_seg7_texture_07001000 = { "wood", "32x32" },
    lll_seg7_texture_07002000 = { "tile", "32x32" },
    lll_seg7_texture_07002800 = { "stone", "32x32" },
    lll_seg7_texture_07003000 = { "brick", "32x32" },
    lll_seg7_texture_07003800 = { "stone", "32x32" },
    lll_seg7_texture_07004000 = { "stone", "32x32" },
    lll_seg7_texture_07004800 = { "brick", "32x32" },
    lll_seg7_texture_07005000 = { "tile", "32x32" },
    lll_seg7_texture_07005800 = { "stone", "32x32" },
    lll_seg7_texture_0700D400 = { "metal", "32x32" },
    lll_seg7_texture_0700DC00 = { "wood", "32x32" },
    lll_seg7_texture_0700E400 = { "lava", "32x32" },
    lll_seg7_texture_0700EC00 = { "lava", "32x32" },
    machine_09000000 = { "brassframe", "32x32" },
    machine_09000800 = { "stone", "32x32" },
    machine_09001000 = { "metal", "32x32" },
    machine_09002000 = { "metal", "32x32" },
    machine_09002800 = { "metal", "32x32" },
    machine_09003800 = { "metal", "32x32" },
    machine_09005800 = { "metal", "32x32" },
    machine_09006000 = { "metal", "32x32" },
    machine_09006800 = { "metal", "32x32" },
    machine_09007000 = { "metal", "32x32" },
    machine_09008400 = { "tile", "32x32" },
    mountain_09000000 = { "stone", "32x32" },
    mountain_09003800 = { "stone", "32x32" },
    mountain_09004000 = { "stone", "32x32" },
    mountain_09005000 = { "wood", "32x32" },
    mountain_09006800 = { "brick", "32x32" },
    mountain_09007000 = { "wood", "32x32" },
    mountain_09008000 = { "vinepole", "32x32" },
    mountain_09008800 = { "metal", "64x32" },
    mountain_0900A000 = { "vines", "32x32" },
    mountain_0900A800 = { "tile", "32x32" },
    mountain_0900B800 = { "stone", "32x32" },
    outside_09000000 = { "stone", "32x32" },
    outside_09000800 = { "stone", "32x32" },
    outside_09001000 = { "brick", "64x32" },
    outside_09002000 = { "grasscliff", "32x64" },
    outside_09003800 = { "grass", "32x32" },
    outside_09004000 = { "grass", "32x32" },
    outside_09004800 = { "stone", "32x64" },
    outside_09005800 = { "grate", "32x32" },
    outside_09006800 = { "brick", "64x32" },
    outside_09007800 = { "roof", "32x32" },
    outside_09008000 = { "sand", "32x32" },
    outside_09009000 = { "stone", "32x32" },
    outside_09009800 = { "tile", "32x32" },
    outside_0900A000 = { "tile", "32x32" },
    outside_0900B400 = { "wood", "32x32" },
    pss_seg7_texture_07001000 = { "tile", "32x32" },
    sky_09000000 = { "slatfence", "32x32" },
    sky_09000800 = { "wood", "32x32" },
    sky_09001000 = { "brick", "32x32" },
    sky_09001800 = { "stone", "32x32" },
    sky_09003800 = { "mesh", "64x32" },
    sky_09004800 = { "wood", "32x32" },
    sky_09005000 = { "windowframe", "32x32" },
    sky_09006000 = { "vines", "32x32" },
    sky_09007000 = { "stone", "32x32" },
    sky_09007800 = { "metal", "32x32" },
    sky_09008000 = { "tile", "32x32" },
    sl_seg7_texture_07002000 = { "stone", "32x32" },
    snow_09000000 = { "snowplanks", "32x32" },
    snow_09000800 = { "ice", "32x32" },
    snow_09002000 = { "stone", "32x32" },
    snow_09002800 = { "ice", "32x32" },
    snow_09003000 = { "stone", "32x32" },
    snow_09005000 = { "brick", "32x32" },
    snow_09005800 = { "snowposts", "32x32" },
    snow_09006000 = { "snow", "32x32" },
    snow_09006800 = { "frostvine", "32x32" },
    snow_09007000 = { "icicles", "64x32" },
    snow_09008000 = { "wood", "32x32" },
    snow_09008800 = { "ice", "32x32" },
    spooky_09001800 = { "wood", "32x64" },
    spooky_09003800 = { "wood", "32x64" },
    spooky_09004800 = { "stone", "32x32" },
    spooky_09005000 = { "brick", "32x64" },
    spooky_09007000 = { "wood", "64x32" },
    spooky_09008000 = { "bracket", "32x32" },
    spooky_09008800 = { "wood", "32x32" },
    spooky_09009000 = { "wood", "64x32" },
    spooky_0900A000 = { "metal", "32x32" },
    ssl_seg7_texture_07000000 = { "tile", "32x32" },
    texture_waterbox_jrb_water = { "water", "32x32" },
    texture_waterbox_lava = { "lava", "32x32" },
    texture_waterbox_unknown_water = { "water", "32x32" },
    texture_waterbox_water = { "water", "32x32" },
    totwc_seg7_texture_07001000 = { "brick", "32x32" },
    totwc_seg7_texture_07001800 = { "stone", "32x32" },
    ttm_seg7_texture_07001800 = { "wood", "32x32" },
    ttm_seg7_texture_07002000 = { "wood", "32x32" },
    ttm_seg7_texture_07002800 = { "wood", "32x32" },
    ttm_seg7_texture_0702AD30 = { "tile", "32x32" },
    vcutm_seg7_texture_07001800 = { "wood", "32x64" },
    vcutm_seg7_texture_07002800 = { "stone", "32x32" },
    water_09000800 = { "stone", "64x32" },
    water_09001800 = { "stone", "64x32" },
    water_09002800 = { "sand", "64x32" },
    water_09003800 = { "water", "64x32" },
    water_09004800 = { "water", "64x32" },
    water_09006800 = { "water", "64x32" },
    water_09007800 = { "stone", "64x32" },
    water_09009000 = { "stone", "64x32" },
    water_0900A000 = { "wood", "32x32" },
    water_0900A800 = { "stone", "64x32" },
    wdw_seg7_texture_07000000 = { "wood", "32x32" },
    wdw_seg7_texture_07000800 = { "wood", "32x32" },
    wdw_seg7_texture_07001000 = { "stone", "32x32" },
    wf_seg7_texture_07000800 = { "brick", "32x32" },
    wf_seg7_texture_07001000 = { "metal", "32x32" },
}
local SWAP_NEVER = {
    ccm_seg7_texture_07000000 = "alpha",
    ccm_seg7_texture_07000900 = "alpha",
}

local SWAP_POOLS = {

    water = { ["32x32"] = { "of_shf_waterripple" }, ["64x32"] = { "of_shf_waterripplew" } },
    lava = { ["32x32"] = { "of_shf_lavaflow" } },

    diamond = { ["32x32"] = { "of_alp_diamond" } },
    grate = { ["32x32"] = { "of_alp_grate" } },
    mesh = { ["64x32"] = { "of_alp_mesh" } },

    balustrade = { ["32x32"] = { "of_alp_balustrade" } },
    bracket = { ["32x32"] = { "of_alp_bracket" } },
    brassframe = { ["32x32"] = { "of_alp_brassframe" } },
    crossjoint = { ["32x32"] = { "of_alp_crossjoint" } },
    fencebeams = { ["32x32"] = { "of_alp_fencebeams" } },
    frostvine = { ["32x32"] = { "of_alp_frostvine" } },
    icicles = { ["64x32"] = { "of_alp_icicles" } },
    ironfence = { ["32x32"] = { "of_alp_ironfence" } },
    lattice = { ["32x32"] = { "of_alp_lattice" } },
    peg = { ["32x64"] = { "of_alp_peg" } },
    poles = { ["32x32"] = { "of_alp_poles" } },
    postchain = { ["32x32"] = { "of_alp_postchain" } },
    slatfence = { ["32x32"] = { "of_alp_slatfence" } },
    snowplanks = { ["32x32"] = { "of_alp_snowplanks" } },
    snowposts = { ["32x32"] = { "of_alp_snowposts" } },
    vinepole = { ["32x32"] = { "of_alp_vinepole" } },
    vines = { ["32x32"] = { "of_alp_vines" } },
    windowframe = { ["32x32"] = { "of_alp_windowframe" } },

    grass = { ["32x32"] = { "of_shf_grasslush", "of_shf_grassmeadow" },
              ["32x64"] = { "of_shf_grasslusht" }, ["64x32"] = { "of_shf_grasslushw" } },
    grassedge = { ["32x32"] = { "of_shf_grassside" } },
    grasscliff = { ["32x32"] = { "of_shf_grasscliffside" }, ["32x64"] = { "of_shf_grassclifft" } },
    carpet = { ["32x32"] = { "of_shf_carpetred" } },
    dirt = { ["32x32"] = { "of_shf_dirtbrown", "of_shf_gravel" }, ["32x64"] = { "of_shf_dirtbrownt" } },
    sand = { ["32x32"] = { "of_shf_sandbeach", "of_shf_sanddune", "of_shf_sandstone" },
             ["32x64"] = { "of_shf_sandstonelayeredt" }, ["64x32"] = { "of_shf_sandbeachw" } },
    snow = { ["32x32"] = { "of_shf_snowfresh" } },
    ice = { ["32x32"] = { "of_shf_icesmooth" }, ["32x64"] = { "of_shf_icebrickt" } },
    wood = { ["32x32"] = { "of_shf_wdbirch", "of_shf_wdoak", "of_shf_wdpine", "of_shf_wdvertblue" },
             ["32x64"] = { "of_shf_wdvertredt" }, ["64x32"] = { "of_shf_wdvertw" } },
    brick = { ["32x32"] = { "of_shf_brbrown", "of_shf_brred", "of_shf_bryellow", "of_shf_adobe" },
              ["32x64"] = { "of_shf_brclinkert" }, ["64x32"] = { "of_shf_brstackw" } },
    tile = { ["32x32"] = { "of_shf_cuttile", "of_shf_hexpave", "of_shf_marblerose",
                           "of_shf_marblewhite", "of_shf_terracotta" },
             ["32x64"] = { "of_shf_marblewhitet" }, ["64x32"] = { "of_shf_cuttilew" } },
    metal = { ["32x32"] = { "of_shf_steelplate", "of_shf_copperpatina" },
              ["64x32"] = { "of_shf_steelcorrugatedw" } },
    roof = { ["32x32"] = { "of_shf_rfclay", "of_shf_rfslate" }, ["64x32"] = { "of_shf_rfshinglew" } },
    stone = { ["32x32"] = { "of_shf_basaltrough", "of_shf_castlegrey", "of_shf_castlesand",
                            "of_shf_cobble", "of_shf_flagslate", "of_shf_setts",
                            "of_shf_sbblue", "of_shf_sbgrey", "of_shf_sblarge" },
              ["32x64"] = { "of_shf_castlebluet", "of_shf_rockgreyt" },
              ["64x32"] = { "of_shf_cobblewarmw", "of_shf_sbsmallw" } },
}
local SWAP_NEAR = { snow = "ice", ice = "snow" }

texshuffle.SWAP_POOLS = SWAP_POOLS

function texshuffle.swap_pool(kind, class)
    local own = SWAP_POOLS[kind]
    if own ~= nil and own[class] ~= nil then return own[class] end
    local near = SWAP_NEAR[kind]
    local other = near ~= nil and SWAP_POOLS[near] or nil
    return other ~= nil and other[class] or nil
end

local function name_hash(name)
    local h = 0
    for index = 1, #name do h = (h * 131 + string.byte(name, index)) % 2147483648 end
    return h
end

function texshuffle.swap_mapping()
    local map = {}
    for name, row in pairs(SWAP_KINDS) do

        local pool = SWAP_NEVER[name] == nil and texshuffle.swap_pool(row[1], row[2]) or nil
        if pool ~= nil and #pool > 0 then
            map[name] = pool[name_hash(name) % #pool + 1]
        end
    end
    return map
end

function texshuffle.swap_never(name)
    return SWAP_NEVER[name]
end

function texshuffle.swap_never_names()
    local out = {}
    for name in pairs(SWAP_NEVER) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function texshuffle.swap_kind(name)
    local row = SWAP_KINDS[name]
    if row == nil then return nil end
    return row[1], row[2]
end

function texshuffle.swap_in_force()
    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return false
    end
    return OF.util.asks(OF.modifiers, "is_on")
        and OF.modifiers.is_on(texshuffle.SWAP_KEY) == true
end

texshuffle.MIX_KEY = "ofTexMix"
local roomWasOn = nil
local mineWasOn = false
local mineMix = 0

local function fresh_mix()
    return math.random(1, 2147483646)
end

function texshuffle.keep_mix()
    if not OF.util.is_host() then return false end
    if not OF.util.asks(OF.modifiers, "active") then return false end
    local on = (OF.modifiers.active()[texshuffle.MODIFIER_KEY] or 0) > 0
    local have = tonumber(gGlobalSyncTable[texshuffle.MIX_KEY]) or 0
    local wrote = false
    if on and have <= 0 then
        OF.util.publish(texshuffle.MIX_KEY, fresh_mix())
        wrote = true
    elseif not on and have > 0 then
        OF.util.publish(texshuffle.MIX_KEY, nil)
        wrote = true
    end
    roomWasOn = on
    return wrote
end

local function dealt_seed()
    local level, yours = 0, false
    if OF.util.asks(OF.modifiers, "in_force") then
        level, yours = OF.modifiers.in_force(texshuffle.MODIFIER_KEY)
    end
    local mine = yours == true and (level or 0) > 0
    if mine and not mineWasOn then mineMix = fresh_mix() end
    mineWasOn = mine
    if mine then return mineMix end
    local room = tonumber(gGlobalSyncTable[texshuffle.MIX_KEY]) or 0
    if room > 0 then return math.floor(room) end

    return 0
end

function texshuffle.in_force_seed()
    if OF.util.asks(OF.lockdown, "menu_stands_down")
        and OF.lockdown.menu_stands_down() then
        return 0
    end
    if OF.rando ~= nil and type(OF.rando.layer_seed) == "function" then
        local drawn = OF.rando.layer_seed()
        if type(drawn) == "number" and drawn > 0 then return drawn end
    end
    if OF.util.asks(OF.modifiers, "is_on")
        and OF.modifiers.is_on(texshuffle.MODIFIER_KEY) then
        return dealt_seed()
    end
    return 0
end

function texshuffle.in_force()
    return texshuffle.in_force_seed() > 0
end

local appliedSeed = nil
local appliedTargets = {}

local function clear_applied()
    for _, name in ipairs(appliedTargets) do
        texture_override_reset(name)
    end
    appliedTargets = {}
end

local APPLY_PER_FRAME = 240
local pending = {}
local pendingAt = 0

local function apply_mapping(seed, map)
    clear_applied()
    pending, pendingAt = {}, 0
    if seed ~= 0 then
        for target, replacement in pairs(map) do
            table.insert(pending, { target, replacement })
        end
        table.sort(pending, function(a, b) return a[1] < b[1] end)
    end
    appliedSeed = seed
end

local function apply_some()
    local last = math.min(#pending, pendingAt + APPLY_PER_FRAME)
    for index = pendingAt + 1, last do
        local one = pending[index]
        texture_override_set(one[1], get_texture_info(one[2]))
        table.insert(appliedTargets, one[1])
    end
    pendingAt = last
    return last < #pending
end

texshuffle.SWAP_MARK = -1
function texshuffle.in_force_key()
    local seed = texshuffle.in_force_seed()
    if seed > 0 then return seed end
    if texshuffle.swap_in_force() then return texshuffle.SWAP_MARK end
    return 0
end

function texshuffle.tick()
    texshuffle.keep_mix()
    local wanted = texshuffle.in_force_key()
    if wanted ~= appliedSeed then
        local map = wanted == texshuffle.SWAP_MARK and texshuffle.swap_mapping()
            or texshuffle.mapping(wanted)
        apply_mapping(wanted, map)
        apply_some()
        return true
    end
    if pendingAt < #pending then apply_some() return true end
    return false
end

hook_event(HOOK_UPDATE, function() texshuffle.tick() end)

hook_event(HOOK_ON_EXIT, function() clear_applied() end)

function texshuffle.ready()
    return true
end
