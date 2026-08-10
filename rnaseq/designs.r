# Design-matrix constructors for common differential-expression models.
#
# Further reading:
# Law CW et al. (2020), "A guide to creating design matrices for gene
# expression experiments", doi:10.12688/f1000research.27893.1.

# Internal validation -------------------------------------------------------

.designInputName <- function(name) {
  paste0("`", name, "`")
}

.validateNumericDesignInput <- function(x, name) {
  if (!is.numeric(x) || is.object(x) || !is.null(dim(x))) {
    stop(.designInputName(name), " must be a numeric vector.", call. = FALSE)
  }
  if (length(x) == 0L) {
    stop(.designInputName(name), " must not be empty.", call. = FALSE)
  }
  if (anyNA(x) || any(!is.finite(x))) {
    stop(
      .designInputName(name),
      " must not contain missing or non-finite values.",
      call. = FALSE
    )
  }
}

.validateFactorDesignInput <- function(x, name, exactLevels = NULL) {
  if (!is.factor(x)) {
    stop(.designInputName(name), " must be a factor.", call. = FALSE)
  }
  if (length(x) == 0L) {
    stop(.designInputName(name), " must not be empty.", call. = FALSE)
  }
  if (anyNA(x)) {
    stop(.designInputName(name), " must not contain missing values.", call. = FALSE)
  }

  observed <- tabulate(x, nbins = nlevels(x))
  if (any(observed == 0L)) {
    unused <- levels(x)[observed == 0L]
    stop(
      .designInputName(name),
      " has unused levels: ",
      paste(unused, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  if (nlevels(x) < 2L) {
    stop(.designInputName(name), " must have at least two levels.", call. = FALSE)
  }
  if (!is.null(exactLevels) && nlevels(x) != exactLevels) {
    stop(
      .designInputName(name),
      " must have exactly ",
      exactLevels,
      " levels.",
      call. = FALSE
    )
  }
}

.validateScalarInteger <- function(x, name) {
  if (
    length(x) != 1L ||
    !is.numeric(x) ||
    is.object(x) ||
    is.na(x) ||
    !is.finite(x) ||
    x < 1 ||
    x %% 1 != 0
  ) {
    stop(
      .designInputName(name),
      " must be a positive integer.",
      call. = FALSE
    )
  }
}

.validateScalarPositive <- function(x, name) {
  if (
    length(x) != 1L ||
    !is.numeric(x) ||
    is.object(x) ||
    is.na(x) ||
    !is.finite(x) ||
    x <= 0
  ) {
    stop(
      .designInputName(name),
      " must be a positive finite number.",
      call. = FALSE
    )
  }
}

.designSampleNames <- function(inputs) {
  inputLengths <- lengths(inputs)
  if (length(unique(inputLengths)) != 1L) {
    details <- paste0(names(inputs), "=", inputLengths, collapse = ", ")
    stop("Design inputs must have equal lengths (", details, ").", call. = FALSE)
  }

  namedInputs <- lapply(inputs, names)
  namedInputs <- namedInputs[lengths(namedInputs) > 0L]
  if (length(namedInputs) == 0L) {
    return(NULL)
  }

  sampleNames <- namedInputs[[1L]]
  if (
    anyNA(sampleNames) ||
    any(sampleNames == "") ||
    anyDuplicated(sampleNames)
  ) {
    stop(
      "Input vector names must be non-missing, non-empty, and unique.",
      call. = FALSE
    )
  }
  if (any(!vapply(namedInputs, identical, logical(1L), sampleNames))) {
    stop("Input vector names must match and have the same order.", call. = FALSE)
  }

  sampleNames
}

.designData <- function(inputs) {
  sampleNames <- .designSampleNames(inputs)
  inputs <- lapply(inputs, unname)
  data <- as.data.frame(inputs, optional = TRUE, stringsAsFactors = FALSE)
  if (!is.null(sampleNames)) {
    rownames(data) <- sampleNames
  }
  data
}

.requireCompleteFactorial <- function(inputs) {
  counts <- do.call(table, c(lapply(inputs, unname), list(useNA = "no")))
  if (any(counts == 0L)) {
    stop(
      "Every combination of ",
      paste(vapply(names(inputs), .designInputName, character(1L)),
            collapse = " and "),
      " must be observed.",
      call. = FALSE
    )
  }
}

.finalizeDesign <- function(design) {
  if (!is.matrix(design) || !is.numeric(design)) {
    stop("Internal error: the constructed design is not a numeric matrix.",
         call. = FALSE)
  }

  decomposition <- qr(design)
  if (decomposition$rank < ncol(design)) {
    dependent <- decomposition$pivot[
      seq.int(decomposition$rank + 1L, ncol(design))
    ]
    stop(
      "The design matrix is not full rank; non-estimable columns: ",
      paste(colnames(design)[dependent], collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  design
}


# Basic models --------------------------------------------------------------

#' Construct a regression design matrix for a numeric covariate
#'
#' Models a linear relationship between expression and a continuous variable.
#' The first coefficient is expected expression when `covariate` is zero; the
#' second is the expected change per unit increase in `covariate`.
#'
#' @param covariate A finite numeric vector with one value per sample.
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixCovariate <- function(covariate) {
  .validateNumericDesignInput(covariate, "covariate")
  data <- .designData(list(covariate = covariate))
  .finalizeDesign(stats::model.matrix(~covariate, data = data))
}

#' Construct a through-origin regression design matrix
#'
#' Models a linear relationship constrained to have zero expected expression
#' when `covariate` is zero. Its only coefficient is the expected change per
#' unit increase in `covariate`. This is not equivalent to
#' [modelMatrixCovariate()] and is appropriate only when the zero constraint is
#' scientifically justified.
#'
#' @inheritParams modelMatrixCovariate
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixCovariateThroughOrigin <- function(covariate) {
  .validateNumericDesignInput(covariate, "covariate")
  data <- .designData(list(covariate = covariate))
  .finalizeDesign(stats::model.matrix(~0 + covariate, data = data))
}

#' Construct a mean-reference factor design matrix
#'
#' Uses treatment contrasts to compare every non-reference level with a common
#' reference. The intercept is the expected expression for the factor's first
#' level; each remaining coefficient is the difference between that level and
#' the reference. This parameterization is useful when comparisons with a
#' control or baseline should be estimated directly.
#'
#' @param group A factor with one value per sample. Its declared first level is
#'   used as the reference.
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixFactorReference <- function(group) {
  .validateFactorDesignInput(group, "group")
  data <- .designData(list(group = group))
  .finalizeDesign(stats::model.matrix(~group, data = data))
}

#' Construct a factor means design matrix
#'
#' Uses a no-intercept parameterization in which each coefficient is the
#' expected expression for one factor level. This form is convenient for
#' pairwise comparisons and contrasts between averages of several levels.
#'
#' A factor that is completely determined by `group` must not be added as a
#' separate effect: it contains no independent information and would make the
#' design rank-deficient.
#'
#' @inheritParams modelMatrixFactorReference
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixFactorMeans <- function(group) {
  .validateFactorDesignInput(group, "group")
  data <- .designData(list(group = group))
  .finalizeDesign(stats::model.matrix(~0 + group, data = data))
}


# Treatment and multifactor models -----------------------------------------

#' Construct a two-treatment interaction design matrix
#'
#' Uses a means model with one coefficient for each combination of two binary
#' factors. Both inputs must have two levels and all four combinations must be
#' observed. An interaction is tested with a difference-of-differences contrast
#' between the four cell means.
#'
#' @param treat1 A two-level factor indicating the first treatment.
#' @param treat2 A two-level factor indicating the second treatment.
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixTreatmentInteraction <- function(treat1, treat2) {
  .validateFactorDesignInput(treat1, "treat1", exactLevels = 2L)
  .validateFactorDesignInput(treat2, "treat2", exactLevels = 2L)
  .designSampleNames(list(treat1 = treat1, treat2 = treat2))
  .requireCompleteFactorial(list(treat1 = treat1, treat2 = treat2))
  data <- .designData(list(treat1 = treat1, treat2 = treat2))
  .finalizeDesign(stats::model.matrix(~0 + treat1:treat2, data = data))
}

#' Construct an additive two-treatment design matrix
#'
#' Models the main effects of two binary factors without an interaction term.
#' Both inputs must have two levels and all four combinations must be observed.
#' The joint effect is therefore constrained to equal the sum of the two main
#' effects. Use [modelMatrixTreatmentInteraction()] when that assumption needs
#' to be tested rather than imposed.
#'
#' A pure cell-means parameterization is not identifiable under the additivity
#' constraint. This no-intercept parameterization therefore estimates the two
#' `treat1` means when `treat2` is at its first level, plus the common shift
#' associated with the second level of `treat2`.
#'
#' @inheritParams modelMatrixTreatmentInteraction
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixTreatmentAdditive <- function(treat1, treat2) {
  .validateFactorDesignInput(treat1, "treat1", exactLevels = 2L)
  .validateFactorDesignInput(treat2, "treat2", exactLevels = 2L)
  .designSampleNames(list(treat1 = treat1, treat2 = treat2))
  .requireCompleteFactorial(list(treat1 = treat1, treat2 = treat2))
  data <- .designData(list(treat1 = treat1, treat2 = treat2))
  .finalizeDesign(stats::model.matrix(~0 + treat1 + treat2, data = data))
}

#' Construct means for every combination of two factors
#'
#' Treats every observed combination of two categorical variables as a distinct
#' group. Each coefficient is the expected expression for one combination.
#' This parameterization makes simple effects, marginal effects, and
#' differences of differences expressible as contrasts of group means. Every
#' combination must be observed. Levels are ordered using [interaction()] with
#' the first factor varying fastest.
#'
#' For repeated observations fitted as a mixed model, subject identifiers remain
#' separate from this fixed-effect matrix and can be supplied as a blocking
#' variable to the model-fitting function.
#'
#' @param factor1 The first factor, with one value per sample.
#' @param factor2 The second factor, with one value per sample.
#'
#' @return A full-rank numeric design matrix with one column per factor
#'   combination.
#'
#' @export
modelMatrixCombinedFactors <- function(factor1, factor2) {
  .validateFactorDesignInput(factor1, "factor1")
  .validateFactorDesignInput(factor2, "factor2")
  sampleNames <- .designSampleNames(
    list(factor1 = factor1, factor2 = factor2)
  )
  .requireCompleteFactorial(list(factor1 = factor1, factor2 = factor2))

  group <- interaction(factor1, factor2, sep = "_", drop = TRUE)
  names(group) <- sampleNames
  data <- .designData(list(group = group))
  .finalizeDesign(stats::model.matrix(~0 + group, data = data))
}

#' Construct group means adjusted for technical factors
#'
#' Estimates a mean for each biological group while controlling for two
#' categorical nuisance variables. Group means are represented directly;
#' `lane` and `technician` coefficients represent differences from their first
#' levels. The names reflect common technical effects, but either argument can
#' represent another categorical adjustment factor.
#'
#' Adjustment effects must vary independently enough from `group` to be
#' estimable. Confounded inputs produce a rank-deficient design and are
#' rejected.
#'
#' @param group A factor defining the biological groups of interest.
#' @param lane A factor defining sequencing lanes.
#' @param technician A factor defining handling technicians.
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixAdjustedGroups <- function(group, lane, technician) {
  .validateFactorDesignInput(group, "group")
  .validateFactorDesignInput(lane, "lane")
  .validateFactorDesignInput(technician, "technician")
  data <- .designData(
    list(group = group, lane = lane, technician = technician)
  )
  .finalizeDesign(
    stats::model.matrix(~0 + group + lane + technician, data = data)
  )
}

#' Construct a fixed-effect repeated treatment-by-time design matrix
#'
#' Accounts for pairing by estimating one baseline coefficient per subject.
#' Two additional coefficients estimate the average change from baseline within
#' each treatment. Their difference tests whether change over time differs
#' between treatments.
#'
#' Each subject must belong to exactly one treatment and have exactly one
#' observation at each of two timepoints.
#'
#' @param id A factor identifying subjects.
#' @param treatment A two-level treatment factor.
#' @param timepoint A two-level factor whose first level is baseline.
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixRepeatedTreatmentTime <- function(id, treatment, timepoint) {
  .validateFactorDesignInput(id, "id")
  .validateFactorDesignInput(treatment, "treatment", exactLevels = 2L)
  .validateFactorDesignInput(timepoint, "timepoint", exactLevels = 2L)
  data <- .designData(
    list(id = id, treatment = treatment, timepoint = timepoint)
  )

  treatmentsPerSubject <- tapply(
    as.character(treatment),
    id,
    function(x) length(unique(x))
  )
  if (any(treatmentsPerSubject != 1L)) {
    stop("Each `id` must belong to exactly one treatment.", call. = FALSE)
  }

  observations <- table(id, timepoint)
  if (any(observations != 1L)) {
    stop(
      "Each `id` must have exactly one observation at each timepoint.",
      call. = FALSE
    )
  }

  design <- stats::model.matrix(~0 + id, data = data)
  secondTimepoint <- levels(timepoint)[2L]
  changes <- vapply(
    levels(treatment),
    function(level) treatment == level & timepoint == secondTimepoint,
    logical(length(treatment))
  )
  rownames(changes) <- rownames(data)
  design <- cbind(design, changes)
  .finalizeDesign(design)
}

#' Construct treatment-specific linear time trends
#'
#' Models a continuous time trend that may differ between two treatments. The
#' first two coefficients are treatment-specific expected values when `time`
#' is zero. The remaining two coefficients are treatment-specific time slopes.
#' Both treatments must be observed at enough distinct times for every
#' coefficient to be estimable.
#'
#' @param treatment A two-level treatment factor.
#' @param time A finite numeric time vector.
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixTreatmentTime <- function(treatment, time) {
  .validateFactorDesignInput(treatment, "treatment", exactLevels = 2L)
  .validateNumericDesignInput(time, "time")
  data <- .designData(list(treatment = treatment, time = time))
  .finalizeDesign(
    stats::model.matrix(~0 + treatment + treatment:time, data = data)
  )
}


# Nonlinear and cyclical time models ---------------------------------------

#' Construct an orthogonal quadratic time design matrix
#'
#' Models one change in the direction or rate of a time trend using a
#' second-degree orthogonal polynomial. Orthogonal terms reduce collinearity
#' compared with raw powers of time. Their coefficients describe basis
#' components rather than the familiar raw linear and squared terms. At least
#' three distinct time values are required.
#'
#' @param time A finite numeric time vector.
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixQuadraticTime <- function(time) {
  .validateNumericDesignInput(time, "time")
  if (length(unique(time)) < 3L) {
    stop("`time` must contain at least three distinct values.", call. = FALSE)
  }
  data <- .designData(list(time = time))
  .finalizeDesign(
    stats::model.matrix(~stats::poly(time, degree = 2L), data = data)
  )
}

#' Construct an orthogonal cubic time design matrix
#'
#' Models up to two changes in the direction or rate of a time trend using a
#' third-degree orthogonal polynomial. Orthogonal terms reduce collinearity
#' compared with raw powers of time, but their coefficients describe basis
#' components rather than raw polynomial terms. At least four distinct time
#' values are required.
#'
#' @inheritParams modelMatrixQuadraticTime
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixCubicTime <- function(time) {
  .validateNumericDesignInput(time, "time")
  if (length(unique(time)) < 4L) {
    stop("`time` must contain at least four distinct values.", call. = FALSE)
  }
  data <- .designData(list(time = time))
  .finalizeDesign(
    stats::model.matrix(~stats::poly(time, degree = 3L), data = data)
  )
}

#' Construct a natural-spline time design matrix
#'
#' Models a smooth nonlinear time trend without imposing a global polynomial
#' shape. Natural boundary constraints stabilize the curve near the earliest
#' and latest observations. Choose `df` according to the number of distinct
#' timepoints, replication, and residual degrees of freedom.
#'
#' @param time A finite numeric time vector.
#' @param df A positive integer giving the spline degrees of freedom.
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixSplineTime <- function(time, df) {
  .validateNumericDesignInput(time, "time")
  .validateScalarInteger(df, "df")
  data <- .designData(list(time = time))
  .finalizeDesign(
    stats::model.matrix(~splines::ns(time, df = df), data = data)
  )
}

#' Construct a cyclical time design matrix
#'
#' Models a repeating pattern with a known period using sine and cosine basis
#' terms. Together their coefficients determine the phase and amplitude of the
#' fitted cycle. `cycle` must express a scientifically meaningful period in the
#' same units as `time`.
#'
#' @param time A finite numeric time vector.
#' @param cycle A positive finite number giving the cycle length in the same
#'   units as `time`.
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixCyclicTime <- function(time, cycle) {
  .validateNumericDesignInput(time, "time")
  .validateScalarPositive(cycle, "cycle")
  sinphase <- sin(2 * pi * time / cycle)
  cosphase <- cos(2 * pi * time / cycle)
  names(sinphase) <- names(time)
  names(cosphase) <- names(time)
  data <- .designData(list(sinphase = sinphase, cosphase = cosphase))
  .finalizeDesign(
    stats::model.matrix(~sinphase + cosphase, data = data)
  )
}

#' Construct a cyclical time design with a linear trend
#'
#' Models a repeating pattern superimposed on an overall linear trend. The time
#' coefficient captures long-term change while the sine and cosine coefficients
#' determine the phase and amplitude of oscillation around that trend.
#'
#' @inheritParams modelMatrixCyclicTime
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixCyclicLinearTime <- function(time, cycle) {
  .validateNumericDesignInput(time, "time")
  .validateScalarPositive(cycle, "cycle")
  sinphase <- sin(2 * pi * time / cycle)
  cosphase <- cos(2 * pi * time / cycle)
  names(sinphase) <- names(time)
  names(cosphase) <- names(time)
  data <- .designData(
    list(time = time, sinphase = sinphase, cosphase = cosphase)
  )
  .finalizeDesign(
    stats::model.matrix(~time + sinphase + cosphase, data = data)
  )
}

#' Construct a cyclical time design with a spline trend
#'
#' Models a repeating pattern superimposed on a smooth nonlinear trend. The
#' natural spline captures long-term drift while sine and cosine terms capture
#' oscillation with a known period.
#'
#' @inheritParams modelMatrixSplineTime
#' @inheritParams modelMatrixCyclicTime
#'
#' @return A full-rank numeric design matrix.
#'
#' @export
modelMatrixCyclicSplineTime <- function(time, cycle, df) {
  .validateNumericDesignInput(time, "time")
  .validateScalarPositive(cycle, "cycle")
  .validateScalarInteger(df, "df")
  sinphase <- sin(2 * pi * time / cycle)
  cosphase <- cos(2 * pi * time / cycle)
  names(sinphase) <- names(time)
  names(cosphase) <- names(time)
  data <- .designData(
    list(time = time, sinphase = sinphase, cosphase = cosphase)
  )
  .finalizeDesign(
    stats::model.matrix(
      ~splines::ns(time, df = df) + sinphase + cosphase,
      data = data
    )
  )
}
