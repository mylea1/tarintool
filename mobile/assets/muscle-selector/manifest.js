module.exports = {
  "version": 4,
  "source": "female_body_front.svg + female_body_back.svg + male_body_front.svg + male_body_back.svg",
  "viewBox": {
    "width": 660.46,
    "height": 1206.46
  },
  "base": {
    "female": {
      "front": "female-front-base.svg",
      "back": "female-back-base.svg"
    },
    "male": {
      "front": "male-front-base.svg",
      "back": "male-back-base.svg"
    }
  },
  "overlays": {
    "female": {
      "front": {
        "abs": "female-front-abs.svg",
        "biceps": "female-front-biceps.svg",
        "calves": "female-front-calves.svg",
        "chest": "female-front-chest.svg",
        "deltoids": "female-front-deltoids.svg",
        "forearm": "female-front-forearm.svg",
        "obliques": "female-front-obliques.svg",
        "quadriceps": "female-front-quadriceps.svg",
        "trapezius": "female-front-trapezius.svg",
        "adductors": "female-front-adductors.svg",
        "tibialis": "female-front-tibialis.svg"
      },
      "back": {
        "calves": "female-back-calves.svg",
        "deltoids": "female-back-deltoids.svg",
        "forearm": "female-back-forearm.svg",
        "gluteal": "female-back-gluteal.svg",
        "hamstring": "female-back-hamstring.svg",
        "lower-back": "female-back-lower-back.svg",
        "triceps": "female-back-triceps.svg",
        "trapezius": "female-back-trapezius.svg",
        "upper-back": "female-back-upper-back.svg"
      }
    },
    "male": {
      "front": {
        "abs": "male-front-abs.svg",
        "biceps": "male-front-biceps.svg",
        "calves": "male-front-calves.svg",
        "chest": "male-front-chest.svg",
        "deltoids": "male-front-deltoids.svg",
        "forearm": "male-front-forearm.svg",
        "obliques": "male-front-obliques.svg",
        "quadriceps": "male-front-quadriceps.svg",
        "trapezius": "male-front-trapezius.svg"
      },
      "back": {
        "calves": "male-back-calves.svg",
        "deltoids": "male-back-deltoids.svg",
        "forearm": "male-back-forearm.svg",
        "gluteal": "male-back-gluteal.svg",
        "hamstring": "male-back-hamstring.svg",
        "lower-back": "male-back-lower-back.svg",
        "triceps": "male-back-triceps.svg",
        "trapezius": "male-back-trapezius.svg",
        "upper-back": "male-back-upper-back.svg"
      }
    }
  },
  "interaction": {
    "type": "alpha-mask",
    "source": "gender-specific-svg-overlays",
    "mask": "masks.js"
  }
};
