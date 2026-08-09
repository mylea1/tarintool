import 'exercise_dataset.generated.dart';

/// Lightweight metadata for exercise-dataset-reference media used by the
/// mobile exercise library. The source JSON is converted to Dart at build time
/// so the app does not parse the 17 MB dataset at runtime.
class ExerciseMedia {
  const ExerciseMedia({
    required this.datasetId,
    required this.imageAsset,
    required this.gifAsset,
    required this.summary,
    required this.steps,
    this.attribution = '© Gym visual — https://gymvisual.com/',
  });

  final String datasetId;
  final String imageAsset;
  final String gifAsset;
  final String summary;
  final List<String> steps;
  final String attribution;

  String get imagePath => 'assets/exercises/reference/$imageAsset';
  String get gifPath => 'assets/exercises/reference/$gifAsset';
}

const exerciseMedia = <String, ExerciseMedia>{
  'machine_chest_press': ExerciseMedia(
    datasetId: '0577',
    imageAsset: '0577.jpg',
    gifAsset: '0577.gif',
    summary: '坐稳并让背部贴住靠垫，沿稳定轨迹水平推起手柄。',
    steps: <String>[
      '调整座椅高度，让手柄与胸部中段对齐，背部平放在靠垫上。',
      '正手握住手柄，保持肘部约 90 度并收紧核心。',
      '向前推动手柄至手臂接近伸直，保持肩胛骨稳定。',
      '短暂停顿后控制手柄回到起始位，重复目标次数。',
    ],
  ),
  'machine_crunch': ExerciseMedia(
    datasetId: '1452',
    imageAsset: '1452.jpg',
    gifAsset: '1452.gif',
    summary: '用腹肌完成卷曲，不要用甩头或髋部借力。',
    steps: <String>[
      '坐在器械上，背部靠垫，双脚平放并调整支撑位置。',
      '握住手柄或放在侧垫上，先收紧腹肌。',
      '让上背部随靠垫向前卷曲，胸部靠近膝盖。',
      '在顶部停顿后慢慢还原，保持腰部受控。',
    ],
  ),
  'standing_hip_abduction': ExerciseMedia(
    datasetId: '0710',
    imageAsset: '0710.jpg',
    gifAsset: '0710.gif',
    summary: '保持骨盆水平，用臀中肌把腿向侧面打开。',
    steps: <String>[
      '双脚与肩同宽站立，躯干保持直立并收紧核心。',
      '将重心移到一侧腿，另一条腿保持伸直向侧面抬起。',
      '在顶端短暂停顿，避免身体向支撑侧倾斜。',
      '缓慢放回并换边，按目标次数交替完成。',
    ],
  ),
  'seated_hip_abduction': ExerciseMedia(
    datasetId: '0597',
    imageAsset: '0597.jpg',
    gifAsset: '0597.gif',
    summary: '坐稳后向外打开膝盖，回程也保持张力。',
    steps: <String>[
      '调整座椅使膝盖约 90 度，背部靠紧靠背。',
      '双脚放在脚踏板，双手握住侧手柄保持稳定。',
      '启动臀中肌，缓慢将双腿分开远离身体中线。',
      '顶端停顿后控制双腿回到起始位置。',
    ],
  ),
  'chest_supported_row': ExerciseMedia(
    datasetId: '1318',
    imageAsset: '1318.jpg',
    gifAsset: '1318.gif',
    summary: '胸口有支撑时优先让肩胛骨后缩，再把手柄拉向胸部。',
    steps: <String>[
      '将上斜凳设为约 45 度，手柄连接低位滑轮。',
      '胸口贴住凳面，双臂前伸并保持背部自然。',
      '先收回肩胛骨，再屈肘把手柄拉向胸部。',
      '顶端挤压背部后，控制手臂回到起始位。',
    ],
  ),
  't_bar_row': ExerciseMedia(
    datasetId: '0606',
    imageAsset: '0606.jpg',
    gifAsset: '0606.gif',
    summary: '胸部贴垫、躯干稳定，避免用耸肩带动重量。',
    steps: <String>[
      '调整座椅和踏板，让胸部舒适贴在支撑垫上。',
      '略宽于肩握住手柄，背部挺直并收紧核心。',
      '将手柄拉向躯干，同时挤压肩胛骨。',
      '收缩顶端停顿后缓慢放回，保持全程可控。',
    ],
  ),
  'plate_loaded_pulldown': ExerciseMedia(
    datasetId: '0579',
    imageAsset: '0579.jpg',
    gifAsset: '0579.gif',
    summary: '挺胸下拉至上胸，先让肩胛下沉再弯曲肘部。',
    steps: <String>[
      '调整座椅和膝垫，双脚平放并稳定身体。',
      '略宽于肩正手握住手柄，胸口抬起。',
      '收紧背阔肌，将手柄向下拉向上胸。',
      '底部停顿后控制手柄上行，不要耸肩代偿。',
    ],
  ),
  'plate_loaded_romanian_deadlift': ExerciseMedia(
    datasetId: '1459',
    imageAsset: '1459.jpg',
    gifAsset: '1459.gif',
    summary: '以髋部后移为主，保持负重贴近身体并感受腿后侧拉伸。',
    steps: <String>[
      '双脚与肩同宽站立，双手握住负重，核心收紧。',
      '保持背部挺直，以髋部为铰链向后坐。',
      '让负重沿腿部下移，直到腿后侧有明显拉伸。',
      '脚跟发力、收紧臀肌回到站立位，避免过度挺腰。',
    ],
  ),
  'single_arm_pulldown': ExerciseMedia(
    datasetId: '3563',
    imageAsset: '3563.jpg',
    gifAsset: '3563.gif',
    summary: '单侧下拉时保持躯干安静，让肘部沿身体侧面下行。',
    steps: <String>[
      '将单手柄连接到高位滑轮，站姿或跪姿保持稳定。',
      '正手握住手柄，手臂完全伸展且肩膀下沉。',
      '保持背部挺直，将肘部贴近身体向下拉。',
      '底部挤压背阔肌后慢慢还原，再换另一侧。',
    ],
  ),
  'hack_squat': ExerciseMedia(
    datasetId: '0743',
    imageAsset: '0743.jpg',
    gifAsset: '0743.gif',
    summary: '沿器械轨迹下蹲，膝盖与脚尖同向并控制深度。',
    steps: <String>[
      '调整肩垫和平台位置，双脚与肩同宽、脚尖略向外。',
      '握稳把手，保持胸口抬起并收紧核心。',
      '弯曲膝髋向下，直到大腿接近平行或达到舒适深度。',
      '脚跟发力推回起始位，避免膝盖内扣。',
    ],
  ),
  'hip_thrust': ExerciseMedia(
    datasetId: '3236',
    imageAsset: '3236.jpg',
    gifAsset: '3236.gif',
    summary: '在顶端完成髋伸展，保持肋骨下沉并挤压臀肌。',
    steps: <String>[
      '跪姿或坐姿固定阻力带，膝盖与髋同宽。',
      '收紧核心，保持骨盆中立并准备向前推髋。',
      '臀肌发力将髋部推至伸展，双腿与躯干成直线。',
      '顶端停顿后控制回落，不要用腰椎过度后仰。',
    ],
  ),
  'back_extension': ExerciseMedia(
    datasetId: '0573',
    imageAsset: '0573.jpg',
    gifAsset: '0573.gif',
    summary: '从髋部折叠和伸展，避免在顶端过度抬高腰部。',
    steps: <String>[
      '调好器械尺寸，双脚固定并让背部贴合支撑垫。',
      '收紧核心，从髋部缓慢向前倾，保持颈部中立。',
      '在底部感受下背部和臀腿的受控拉伸。',
      '用后侧链条回到起始位，顶端不要过度挺腰。',
    ],
  ),
  'preacher_curl': ExerciseMedia(
    datasetId: '0070',
    imageAsset: '0070.jpg',
    gifAsset: '0070.gif',
    summary: '上臂贴在牧师凳垫上，完整控制肘关节屈伸。',
    steps: <String>[
      '坐稳牧师凳，让上臂平贴在垫面。',
      '反手握杠，保持肩膀放松和上臂固定。',
      '呼气并弯举至二头肌收缩，顶端短暂停顿。',
      '吸气，慢慢放回起始位，不要在底部弹起。',
    ],
  ),
  'barbell_squat': ExerciseMedia(
    datasetId: '0043',
    imageAsset: '0043.jpg',
    gifAsset: '0043.gif',
    summary: '保持足底稳定、膝盖跟随脚尖，髋膝同步下蹲。',
    steps: <String>[
      '双脚与肩同宽，杠铃稳放在上背部而非颈部。',
      '收紧核心、抬起胸口，髋部向后并向下。',
      '下蹲至大腿接近平行，膝盖与脚尖保持同向。',
      '脚跟发力站起，伸展髋和膝回到起始位。',
    ],
  ),
  'goblet_squat': ExerciseMedia(
    datasetId: '1760',
    imageAsset: '1760.jpg',
    gifAsset: '1760.gif',
    summary: '把负重贴近胸口，保持躯干直立并稳定完成深度。',
    steps: <String>[
      '双手托住哑铃垂直贴近胸前，双脚与肩同宽。',
      '保持胸口抬起和核心收紧，髋部向后坐。',
      '屈膝下蹲至舒适深度，膝盖跟随脚尖。',
      '底部停顿后脚跟发力站起，保持负重靠近身体。',
    ],
  ),
  'deadlift': ExerciseMedia(
    datasetId: '0032',
    imageAsset: '0032.jpg',
    gifAsset: '0032.gif',
    summary: '让杠铃沿小腿垂直移动，用髋膝伸展完成站起。',
    steps: <String>[
      '杠铃贴近小腿，双脚与肩同宽，髋部向后。',
      '屈膝并保持背部平直，双手略宽于肩握杠。',
      '脚跟推地，伸展膝髋将杠铃沿身体拉起。',
      '站直时挤压臀肌，再以髋部后移将杠铃放回地面。',
    ],
  ),
  'romanian_deadlift': ExerciseMedia(
    datasetId: '0085',
    imageAsset: '0085.jpg',
    gifAsset: '0085.gif',
    summary: '膝盖只略微弯曲，持续用髋部后移拉伸腿后侧。',
    steps: <String>[
      '双脚与肩同宽，正手握杠并保持肋骨下沉。',
      '膝盖微屈，以髋部为铰链向后推。',
      '让杠铃贴近身体向下，直到腿后侧明显拉伸。',
      '髋部向前推回站立，顶端挤压臀肌后重复。',
    ],
  ),
  'bench_press': ExerciseMedia(
    datasetId: '0025',
    imageAsset: '0025.jpg',
    gifAsset: '0025.gif',
    summary: '肩胛稳定、前臂垂直，让杠铃受控触胸后推起。',
    steps: <String>[
      '平躺在凳上，双脚踩地，肩胛骨向后下方收紧。',
      '略宽于肩正手握杠，将杠铃置于胸部上方。',
      '控制杠铃下放至胸部中段，肘部保持适度内收。',
      '短暂停顿后伸展双臂推回起始位，保持手腕中立。',
    ],
  ),
  'dumbbell_press': ExerciseMedia(
    datasetId: '0314',
    imageAsset: '0314.jpg',
    gifAsset: '0314.gif',
    summary: '上斜凳稳定肩胛，双侧哑铃同步下放与推起。',
    steps: <String>[
      '将凳子调到约 45 度，双脚踩地并贴住靠背。',
      '哑铃举至肩高，掌心向前、肘部稍低于肩。',
      '控制哑铃下放到胸部两侧，保持前臂接近垂直。',
      '推回起始位并充分伸展手臂，避免肩膀前移。',
    ],
  ),
  'shoulder_press': ExerciseMedia(
    datasetId: '0405',
    imageAsset: '0405.jpg',
    gifAsset: '0405.gif',
    summary: '坐姿保持躯干稳定，沿肩部自然轨迹向上推举。',
    steps: <String>[
      '坐在有靠背的凳上，哑铃放在大腿上。',
      '将哑铃提到肩高，手掌朝前并收紧核心。',
      '向上推举直到手臂接近伸直，肩膀不要耸起。',
      '顶端停顿后慢慢回到肩高，保持肋骨下沉。',
    ],
  ),
  'push_up': ExerciseMedia(
    datasetId: '0662',
    imageAsset: '0662.jpg',
    gifAsset: '0662.gif',
    summary: '头、肩、髋保持一条直线，用胸肩三头肌完成推地。',
    steps: <String>[
      '从高位平板开始，双手略宽于肩，双脚并拢。',
      '收紧核心，屈肘让身体整体向地面下降。',
      '胸部接近地面时短暂停顿，肩胛保持稳定。',
      '伸直手臂推回起始位，避免髋部塌陷。',
    ],
  ),
  'dip': ExerciseMedia(
    datasetId: '0251',
    imageAsset: '0251.jpg',
    gifAsset: '0251.gif',
    summary: '在双杠上保持肩胛稳定，深度以肩部舒适和可控为准。',
    steps: <String>[
      '双臂伸直支撑在双杠上，身体保持稳定。',
      '屈肘控制身体下降，肩膀略低于肘部即可。',
      '保持胸口打开和核心收紧，不要让肩膀前滚。',
      '伸直手臂推回起始位，按可控范围重复。',
    ],
  ),
  'row': ExerciseMedia(
    datasetId: '0180',
    imageAsset: '0180.jpg',
    gifAsset: '0180.gif',
    summary: '坐姿保持脊柱中立，把手柄拉向躯干并夹紧肩胛。',
    steps: <String>[
      '坐在器械上，双脚踩踏板，膝盖保持微屈。',
      '正手握住手柄，背部挺直并略微前倾。',
      '保持躯干稳定，将手柄拉向腹部或胸下缘。',
      '顶端挤压肩胛后慢慢伸臂回到起始位。',
    ],
  ),
  'lat_pulldown': ExerciseMedia(
    datasetId: '2330',
    imageAsset: '2330.jpg',
    gifAsset: '2330.gif',
    summary: '挺胸、肩胛下沉，把横杆拉到上胸而不是颈后。',
    steps: <String>[
      '坐稳并固定膝盖，略宽于肩握住横杆。',
      '胸口抬起，身体只保持轻微后倾。',
      '肩胛下沉，屈肘将横杆拉向上胸。',
      '底部停顿后控制横杆上行，避免耸肩。',
    ],
  ),
  'pull_up': ExerciseMedia(
    datasetId: '0652',
    imageAsset: '0652.jpg',
    gifAsset: '0652.gif',
    summary: '从稳定悬垂开始，让肩胛和肘部共同把胸口拉向横杆。',
    steps: <String>[
      '双手反握或正握横杆，手臂完全伸展并稳定悬垂。',
      '收紧核心，先让肩胛骨下沉并向后。',
      '屈肘把胸口拉向横杆，保持身体不过度摆动。',
      '顶端停顿后控制下降回到悬垂位。',
    ],
  ),
  'face_pull': ExerciseMedia(
    datasetId: '0203',
    imageAsset: '0203.jpg',
    gifAsset: '0203.gif',
    summary: '将绳索拉向脸部两侧，强调后束与肩胛控制。',
    steps: <String>[
      '把绳索连接到低位滑轮，双脚与肩同宽。',
      '正手握绳、掌心相对，膝盖微屈并保持背部平直。',
      '肘部略弯，将绳索向脸部两侧拉开。',
      '顶端挤压后束后慢慢释放张力，避免耸肩。',
    ],
  ),
  'lateral_raise': ExerciseMedia(
    datasetId: '0334',
    imageAsset: '0334.jpg',
    gifAsset: '0334.gif',
    summary: '用肩中束抬起手臂，动作顶端不超过肩高并保持肘部柔软。',
    steps: <String>[
      '双脚与肩同宽站立，哑铃放在身体两侧。',
      '保持背部挺直和核心收紧，肘部略微弯曲。',
      '沿侧面抬起手臂至接近地面平行。',
      '顶端停顿后慢慢放回，避免借力摆动。',
    ],
  ),
  'y_raise': ExerciseMedia(
    datasetId: '1017',
    imageAsset: '1017.jpg',
    gifAsset: '1017.gif',
    summary: '沿斜线上举双臂形成 Y 字，肩胛骨向后下方稳定。',
    steps: <String>[
      '双脚与肩同宽站立，阻力带置于大腿前方。',
      '手掌朝内，保持双臂伸直并收紧核心。',
      '沿斜线把双臂举成 Y 形，不要耸肩。',
      '顶端收紧肩胛后慢慢回到起始位。',
    ],
  ),
  'biceps_curl': ExerciseMedia(
    datasetId: '0031',
    imageAsset: '0031.jpg',
    gifAsset: '0031.gif',
    summary: '固定上臂，只让肘关节屈伸，避免用躯干后仰借力。',
    steps: <String>[
      '双脚与肩同宽站立，反手握住杠铃。',
      '让肘部靠近躯干，收紧核心并保持上臂静止。',
      '呼气弯举至二头肌完全收缩，肩膀不前移。',
      '顶端短暂停顿，吸气控制杠铃回到起始位。',
    ],
  ),
  'triceps_extension': ExerciseMedia(
    datasetId: '0200',
    imageAsset: '0200.jpg',
    gifAsset: '0200.gif',
    summary: '保持上臂贴近身体，只在肘部完成伸展和回程。',
    steps: <String>[
      '将绳索连接到高位滑轮，双脚与肩同宽站立。',
      '掌心相对握绳，肘部贴近身体两侧。',
      '呼气伸展肘部，把绳子推到手臂接近伸直。',
      '短暂停顿后吸气，控制肘部弯曲回到起始位。',
    ],
  ),
  'leg_extension': ExerciseMedia(
    datasetId: '0585',
    imageAsset: '0585.jpg',
    gifAsset: '0585.gif',
    summary: '坐稳并控制膝关节伸展，顶端收紧股四头肌。',
    steps: <String>[
      '调整座椅、靠背与脚垫，让膝轴对齐器械转轴。',
      '背部靠紧靠背，双手握住侧把手保持稳定。',
      '伸直膝盖抬起负重，保持大腿贴住座椅。',
      '顶端停顿后慢慢放下，避免重量撞击。',
    ],
  ),
  'leg_curl': ExerciseMedia(
    datasetId: '0599',
    imageAsset: '0599.jpg',
    gifAsset: '0599.gif',
    summary: '固定大腿、控制脚踝轨迹，用腿后侧完成弯举。',
    steps: <String>[
      '调整座椅与脚垫，脚踝放在软垫下方。',
      '背部靠紧靠背，双手握住侧面把手。',
      '保持大腿不动，呼气向后弯曲小腿。',
      '顶端挤压腿后侧后慢慢放回，保持全程张力。',
    ],
  ),
};

final Map<String, ExerciseMedia> allExerciseMedia = <String, ExerciseMedia>{
  for (final entry in datasetExerciseEntries.entries)
    entry.key: ExerciseMedia(
      datasetId: entry.value.datasetId,
      imageAsset: entry.value.imageAsset,
      gifAsset: entry.value.gifAsset,
      summary: entry.value.summary,
      steps: entry.value.steps,
      attribution: entry.value.attribution,
    ),
  ...exerciseMedia,
};

ExerciseMedia? mediaForExercise(String exerciseId) =>
    allExerciseMedia[exerciseId];
