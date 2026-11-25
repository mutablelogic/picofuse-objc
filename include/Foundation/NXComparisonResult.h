/**
 * @file NXComparisonResult.h
 * @brief Defines the NXComparisonResult type, for the result of a comparison.
 */
#pragma once

/**
 * @brief The order of two objects.
 * @ingroup Foundation
 *
 * \headerfile NXComparisonResult.h Foundation/Foundation.h
 */
typedef enum {
  NXComparisonAscending = -1, ///< The first is before the second
  NXComparisonSame = 0,       ///< They're in the same place
  NXComparisonDescending = 1  ///< The first is after the second
} NXComparisonResult;
