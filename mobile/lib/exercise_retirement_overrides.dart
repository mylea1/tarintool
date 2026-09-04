/// User-requested removals live here so regenerating the scored 300-item list
/// never brings them back. Add stable exercise IDs, not visible names.
///
/// Example workflow: user says "delete 425" -> resolve catalog[424].id -> add
/// that ID below. The complete catalog still retains it for old history.
const manuallyRetiredExerciseIds = <String>{
  'dataset_1368', 'dataset_3293', 'dataset_2355', 'dataset_2333',
  'dataset_3204', 'dataset_3220', 'dataset_3672', 'dataset_3297',
  'dataset_0020', 'dataset_3212', 'dataset_3360', 'dataset_0130',
  'dataset_3019', 'dataset_1770', 'dataset_0139', 'dataset_0140',
  'dataset_3543', 'dataset_3544', 'dataset_1771', 'dataset_1769',
  'dataset_3168', 'dataset_3167', 'dataset_1373', 'dataset_3156',
  'dataset_3158', 'dataset_3162', 'dataset_3161', 'dataset_3166',
  'dataset_3165', 'dataset_1160', 'dataset_0870', 'dataset_1494',
  'dataset_0253', 'dataset_1273', 'dataset_0258', 'dataset_1327',
  'dataset_0259', 'dataset_1468', 'dataset_0267', 'dataset_3016',
  'dataset_0276', 'dataset_0279', 'dataset_0282', 'dataset_0284',
  'dataset_1275', 'dataset_3287', 'dataset_0443', 'dataset_3292',
  'dataset_3303', 'dataset_0456', 'dataset_0457', 'dataset_3470',
  'dataset_2429', 'dataset_3301', 'dataset_3296', 'dataset_3295',
  'dataset_0464', 'dataset_3315', 'dataset_3299', 'dataset_3327',
  'dataset_0466', 'dataset_3561', 'dataset_3523', 'dataset_3193',
  'dataset_0467', 'dataset_0469', 'dataset_1383', 'dataset_1384',
  'dataset_3221', 'dataset_3202', 'dataset_1511', 'dataset_2139',
  'dataset_3218', 'dataset_3215', 'dataset_3302', 'dataset_0471',
  'dataset_1764',
  // 844 resolves to dataset_0472 (hanging leg raise), which the user
  // explicitly retained in the final bodyweight allow-list.
  'dataset_1761', 'dataset_0473', 'dataset_0475', 'dataset_0476',
  'dataset_3636', 'dataset_0484', 'dataset_1418',
};
