from __future__ import annotations

from dataclasses import dataclass


SIDE_VIEWS = ("side", "side_front", "side_rear")
ALL_VIEWS = (*SIDE_VIEWS, "front", "rear")


@dataclass(frozen=True)
class ExerciseRule:
    cameras: tuple[str, ...]
    chain: str
    direction: str
    enter: float
    exit: float
    target: float
    code: str
    label: str
    stage: str
    unilateral: bool = False
    checks: tuple[str, ...] = ()
    limitations: tuple[str, ...] = ()


def _rule(
    cameras: tuple[str, ...],
    chain: str,
    direction: str,
    enter: float,
    exit: float,
    target: float,
    code: str,
    label: str,
    stage: str,
    *,
    unilateral: bool = False,
    checks: tuple[str, ...] = (),
    limitations: tuple[str, ...] = (),
) -> ExerciseRule:
    return ExerciseRule(
        cameras,
        chain,
        direction,
        enter,
        exit,
        target,
        code,
        label,
        stage,
        unilateral,
        checks,
        limitations,
    )


NEW_EXERCISE_RULES: dict[str, ExerciseRule] = {
    "leg_press": _rule(SIDE_VIEWS, "knee", "below", 145, 155, 95, "LEG_PRESS_DEPTH_LIMITED", "下放深度可能不足", "lower_position", checks=("knee_lock",), limitations=("foot_pressure_not_measurable", "seat_setup_not_measurable")),
    "leg_extension": _rule(SIDE_VIEWS, "knee", "above", 150, 120, 160, "LEG_EXT_RANGE_INCOMPLETE", "顶端伸膝幅度不足", "upper_position", checks=("fast_return",), limitations=("pad_contact_not_measurable",)),
    "leg_curl": _rule(SIDE_VIEWS, "knee", "below", 145, 155, 100, "LEG_CURL_RANGE_INCOMPLETE", "屈膝幅度不足", "lower_position", checks=("trunk_stability",)),
    "bulgarian_split_squat": _rule(ALL_VIEWS, "knee", "below", 145, 155, 105, "BSS_DEPTH_LIMITED", "下蹲深度可能不足", "lower_position", unilateral=True, checks=("trunk_stability", "knee_medial")),

    "barbell_row": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 110, "ROW_ELBOW_PULL_LIMITED", "肘部回拉不足", "lower_position", checks=("trunk_stability", "bilateral"), limitations=("bar_path_requires_equipment_detector", "lumbar_spine_shape_not_measurable_with_coco17")),
    "yates_row": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 105, "YRS_RANGE_LIMITED", "拉顶肘角不足", "lower_position", checks=("trunk_stability", "bilateral"), limitations=("lumbar_spine_shape_not_measurable_with_coco17",)),
    "t_bar_row": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 120, "TBAR_RANGE_INCOMPLETE", "拉顶幅度不足", "lower_position", checks=("trunk_stability", "bilateral"), limitations=("bar_path_requires_equipment_detector",)),
    "chest_supported_row": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 110, "CSR_RANGE_INCOMPLETE", "回拉幅度不足", "lower_position", checks=("bilateral", "shoulder_hike")),
    "landmine_one_arm_row": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 115, "LMR_RANGE_LIMITED", "回拉幅度不足", "lower_position", unilateral=True, checks=("trunk_stability", "shoulder_tilt")),
    "half_kneeling_one_arm_row": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 105, "HKR_RANGE_LIMITED", "回拉幅度不足", "lower_position", unilateral=True, checks=("shoulder_tilt",)),
    "standing_one_arm_cable_row": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 105, "SCR_RANGE_LIMITED", "回拉幅度不足", "lower_position", unilateral=True, checks=("trunk_stability", "shoulder_tilt")),
    "upright_row": _rule(ALL_VIEWS, "elbow", "below", 135, 150, 105, "UR_PULL_HEIGHT_LIMITED", "拉起高度不足", "upper_position", checks=("trunk_stability", "shoulder_hike", "bilateral"), limitations=("grip_width_not_measurable", "bar_path_requires_equipment_detector")),
    "one_arm_dumbbell_row": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 115, "OAR_RANGE_LIMITED", "回拉幅度不足", "lower_position", unilateral=True, checks=("shoulder_tilt",)),
    "inverted_row": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 105, "INV_RANGE_LIMITED", "回拉幅度不足", "lower_position", checks=("body_line", "bilateral"), limitations=("foot_anchor_not_measurable", "bar_height_not_measurable")),
    "single_arm_pulldown": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 100, "SA_PULLDOWN_RANGE_INCOMPLETE", "拉到底行程可能不足", "lower_position", unilateral=True, checks=("trunk_stability", "shoulder_tilt"), limitations=("handle_position_not_measurable",)),
    "straight_arm_pulldown": _rule(ALL_VIEWS, "shoulder", "below", 60, 95, 40, "SAP_RANGE_LIMITED", "下压行程不足", "lower_position", checks=("elbow_flexion", "trunk_stability"), limitations=("cable_position_not_measurable",)),
    "underhand_pulldown": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 95, "UHD_RANGE_LIMITED", "拉到底行程不足", "lower_position", checks=("trunk_stability", "bilateral"), limitations=("grip_width_not_measurable",)),
    "chest_supported_pulldown": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 95, "CSP_RANGE_LIMITED", "拉到底行程不足", "lower_position", checks=("trunk_stability", "bilateral")),

    "incline_bench_press": _rule(SIDE_VIEWS, "elbow", "below", 120, 140, 75, "IBP_DEPTH_LIMITED", "下放深度不足", "lower_position", checks=("forearm_vertical",), limitations=("bar_path_requires_equipment_detector", "grip_width_not_measurable")),
    "decline_bench_press": _rule(SIDE_VIEWS, "elbow", "below", 120, 140, 75, "DCP_DEPTH_LIMITED", "下放深度不足", "lower_position", checks=("forearm_vertical", "trunk_stability"), limitations=("leg_anchor_not_measurable", "grip_width_not_measurable")),
    "close_grip_bench_press": _rule(ALL_VIEWS, "elbow", "below", 120, 140, 82, "CGP_DEPTH_LIMITED", "下放深度不足", "lower_position", checks=("forearm_vertical", "bilateral"), limitations=("grip_width_estimated_from_pose_only",)),
    "wide_grip_bench_press": _rule(ALL_VIEWS, "elbow", "below", 120, 140, 75, "WGP_DEPTH_LIMITED", "下放深度不足", "lower_position", checks=("forearm_vertical", "bilateral"), limitations=("grip_width_estimated_from_pose_only",)),
    "barbell_floor_press": _rule(SIDE_VIEWS, "elbow", "below", 125, 145, 105, "FLP_DEPTH_LIMITED", "地板停点偏高", "lower_position", checks=("forearm_vertical",), limitations=("floor_contact_not_measurable",)),
    "machine_shoulder_press": _rule(ALL_VIEWS, "elbow", "above", 135, 115, 155, "MSP_RANGE_INCOMPLETE", "肩推顶端伸展不足", "upper_position", checks=("bilateral", "shoulder_hike")),
    "machine_chest_press": _rule(ALL_VIEWS, "elbow", "above", 145, 120, 150, "MCP_RANGE_INCOMPLETE", "推起行程不足", "upper_position", checks=("bilateral", "trunk_stability", "shoulder_hike"), limitations=("handle_and_seat_setup_not_measurable",)),
    "single_arm_overhead_press": _rule(ALL_VIEWS, "elbow", "above", 135, 115, 150, "SAOP_RANGE_INCOMPLETE", "顶端伸展不足", "upper_position", unilateral=True, checks=("trunk_stability", "shoulder_tilt")),
    "push_press": _rule(ALL_VIEWS, "elbow", "above", 135, 115, 155, "PP_RANGE_INCOMPLETE", "顶端伸展不足", "upper_position", checks=("push_press_dip", "bilateral")),
    "alternate_dumbbell_press": _rule(SIDE_VIEWS, "elbow", "below", 120, 140, 75, "ADP_DEPTH_LIMITED", "单侧下放深度不足", "lower_position", unilateral=True, checks=("forearm_vertical", "trunk_stability"), limitations=("alternating_side_selected_by_motion",)),
    "diamond_push_up": _rule(ALL_VIEWS, "elbow", "below", 130, 150, 95, "DPU_DEPTH_LIMITED", "下降幅度不足", "lower_position", checks=("body_line", "bilateral")),

    "dumbbell_fly": _rule(ALL_VIEWS, "shoulder", "above", 70, 35, 75, "FLY_RANGE_LIMITED", "打开深度不足", "lower_position", checks=("elbow_flexion", "bilateral"), limitations=("supine_geometry_uses_relative_motion",)),
    "cable_fly": _rule(ALL_VIEWS, "shoulder", "below", 60, 100, 40, "CABLE_FLY_RANGE_LIMITED", "夹胸幅度不足", "lower_position", checks=("elbow_flexion", "trunk_stability", "bilateral"), limitations=("cable_and_handles_not_measurable",)),
    "low_to_high_cable_fly": _rule(ALL_VIEWS, "shoulder", "above", 55, 25, 45, "LHF_RANGE_LIMITED", "收尾高度不足", "upper_position", checks=("elbow_flexion", "trunk_stability", "bilateral")),
    "standing_one_arm_cable_fly": _rule(ALL_VIEWS, "shoulder", "below", 45, 90, 35, "SAF_RANGE_LIMITED", "内收幅度不足", "lower_position", unilateral=True, checks=("elbow_flexion", "shoulder_tilt")),
    "pec_deck_fly": _rule(ALL_VIEWS, "shoulder", "below", 40, 80, 35, "PD_RANGE_INCOMPLETE", "合拢幅度不足", "lower_position", checks=("shoulder_hike", "bilateral", "trunk_stability"), limitations=("elbow_pad_contact_not_measurable",)),

    "reverse_fly": _rule(ALL_VIEWS, "shoulder", "above", 45, 25, 65, "REVERSE_FLY_HEIGHT_LIMITED", "抬臂高度不足", "upper_position", checks=("elbow_flexion", "shoulder_hike", "bilateral"), limitations=("scapular_retraction_not_directly_measurable",)),
    "side_lying_lateral_raise": _rule(SIDE_VIEWS, "shoulder", "above", 45, 20, 75, "SLR_HEIGHT_LIMITED", "举起高度不足", "upper_position", unilateral=True, checks=("trunk_stability", "fast_return")),
    "dumbbell_front_raise": _rule(SIDE_VIEWS, "shoulder", "above", 55, 25, 80, "DFR_HEIGHT_LIMITED", "抬臂高度不足", "upper_position", checks=("trunk_stability", "shoulder_hike")),
    "lean_away_lateral_raise": _rule(ALL_VIEWS, "shoulder", "above", 55, 25, 80, "LAL_HEIGHT_LIMITED", "抬臂高度不足", "upper_position", unilateral=True, checks=("trunk_stability",)),
    "bent_over_reverse_fly": _rule(ALL_VIEWS, "shoulder", "above", 45, 25, 60, "BRF_RANGE_LIMITED", "展开幅度不足", "upper_position", checks=("trunk_stability", "shoulder_hike", "bilateral")),
    "cable_reverse_fly": _rule(ALL_VIEWS, "shoulder", "above", 45, 25, 60, "CRF_RANGE_LIMITED", "展开幅度不足", "upper_position", unilateral=True, checks=("trunk_stability", "shoulder_tilt")),
    "machine_reverse_fly": _rule(ALL_VIEWS, "shoulder", "above", 50, 25, 70, "MRF_RANGE_LIMITED", "展开幅度不足", "upper_position", checks=("trunk_stability", "shoulder_hike", "bilateral")),
    "rear_delt_row": _rule(ALL_VIEWS, "elbow", "below", 130, 145, 110, "RDR_RANGE_LIMITED", "回拉幅度不足", "lower_position", checks=("shoulder_hike", "bilateral")),
    "prone_y_raise": _rule(SIDE_VIEWS, "shoulder", "above", 100, 80, 110, "PYR_LIFT_LIMITED", "Y字抬臂幅度不足", "upper_position", checks=("bilateral",), limitations=("prone_geometry_uses_relative_motion",)),

    "dumbbell_pullover": _rule(SIDE_VIEWS, "shoulder", "above", 115, 95, 105, "POL_RANGE_LIMITED", "过头下放深度不足", "upper_position", checks=("elbow_flexion", "trunk_stability"), limitations=("supine_geometry_uses_relative_motion",)),
    "pike_push_up": _rule(SIDE_VIEWS, "elbow", "below", 130, 150, 105, "PPU_DEPTH_LIMITED", "下降幅度不足", "lower_position", checks=("pike_shape", "trunk_stability"), limitations=("head_contact_not_measurable",)),
    "back_extension": _rule(SIDE_VIEWS, "hip", "below", 145, 155, 125, "BACK_EXT_RANGE_LIMITED", "髋部折叠幅度不足", "lower_position", checks=("knee_stability",), limitations=("lumbar_spine_shape_not_measurable_with_coco17", "pad_position_not_measurable")),
    "landmine_press": _rule(SIDE_VIEWS, "shoulder", "above", 90, 70, 95, "LMP_RANGE_LIMITED", "沿斜线推到顶不足", "upper_position", unilateral=True, checks=("trunk_stability",)),
    "incline_dumbbell_press": _rule(SIDE_VIEWS, "elbow", "below", 120, 140, 75, "IDP_DEPTH_LIMITED", "下放深度不足", "lower_position", checks=("forearm_vertical",), limitations=("incline_setup_not_measurable",)),
    "decline_dumbbell_press": _rule(SIDE_VIEWS, "elbow", "below", 120, 140, 75, "DCP_DEPTH_LIMITED", "下放深度不足", "lower_position", checks=("forearm_vertical", "trunk_stability"), limitations=("decline_setup_not_measurable",)),
}


NEW_EXERCISE_IDS = frozenset(NEW_EXERCISE_RULES)
