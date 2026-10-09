# Apple Health Integration

## Data Access Methods

### Method 1: Shortcuts Export (Recommended)
Create an Apple Shortcut to export health data as JSON/CSV:
- Body measurements (weight, body fat %)
- Workouts (type, duration, calories, heart rate)
- Activity (steps, active calories, stand hours)
- Sleep analysis
- Heart rate data

### Method 2: Full Export
Settings → Health → Export All Health Data → share XML file
- Very large file; parse selectively
- Contains all historical data

### Method 3: Screenshot/Photo
User screenshots Health app data → agent analyzes image

## Key Data Types

### Body Measurements
| HealthKit Type | Description | Useful For |
|---------------|-------------|------------|
| HKQuantityTypeIdentifierBodyMass | Weight | Trend tracking |
| HKQuantityTypeIdentifierBodyFatPercentage | Body fat % | Composition tracking |
| HKQuantityTypeIdentifierHeight | Height | BMR calculation |
| HKQuantityTypeIdentifierWaistCircumference | Waist | Visceral fat indicator |
| HKQuantityTypeIdentifierBMI | BMI | General screening |

### Activity
| HealthKit Type | Description | Useful For |
|---------------|-------------|------------|
| HKQuantityTypeIdentifierStepCount | Daily steps | NEAT tracking |
| HKQuantityTypeIdentifierActiveEnergyBurned | Active calories | TDEE estimation |
| HKQuantityTypeIdentifierBasalEnergyBurned | Resting calories | BMR validation |
| HKQuantityTypeIdentifierAppleExerciseTime | Exercise minutes | Activity goals |
| HKQuantityTypeIdentifierAppleStandTime | Stand hours | Sedentary behavior |

### Workouts
| Field | Description |
|-------|-------------|
| workoutActivityType | Exercise type (running, swimming, etc.) |
| duration | Total time in seconds |
| totalEnergyBurned | Calories |
| totalDistance | Meters (if applicable) |
| startDate / endDate | Timestamps |

### Heart Rate
| HealthKit Type | Description | Useful For |
|---------------|-------------|------------|
| HKQuantityTypeIdentifierHeartRate | BPM samples | Training zones |
| HKQuantityTypeIdentifierRestingHeartRate | Resting HR | Cardiovascular fitness |
| HKQuantityTypeIdentifierHeartRateVariability | HRV (SDNN) | Recovery, stress |
| HKQuantityTypeIdentifierWalkingHeartRateAverage | Walking HR | Aerobic fitness |

### Sleep
| HealthKit Type | Description |
|---------------|-------------|
| HKCategoryTypeIdentifierSleepAnalysis | Sleep stages (awake, core, deep, REM) |
| Duration | Total time in bed vs actual sleep |

## Interpretation Guidelines

### Steps → Activity Level
| Steps/Day | Classification |
|-----------|---------------|
| <5,000 | Sedentary |
| 5,000-7,499 | Low active |
| 7,500-9,999 | Somewhat active |
| 10,000-12,499 | Active |
| >12,500 | Highly active |

### Resting Heart Rate → Fitness Level
| RHR (bpm) | Fitness Level |
|-----------|---------------|
| <60 | Excellent |
| 60-69 | Good |
| 70-79 | Average |
| 80-89 | Below average |
| >90 | Poor (or medical condition) |

### HRV (Heart Rate Variability)
- Higher = better recovery, lower stress
- Track personal trends, not absolute values
- Drop of >15% from baseline suggests under-recovery
- Measure consistently (morning, lying down)

### Sleep Quality Indicators
- Total sleep: aim 7-9 hours
- Sleep efficiency: >85% (time asleep / time in bed)
- Deep sleep: 15-20% of total
- REM: 20-25% of total
- Wake episodes: <2-3 per night is normal
