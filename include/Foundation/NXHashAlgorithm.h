/**
 * @file NXHashAlgorithm.h
 * @brief Defines the NXHashAlgorithm type, for algorithms which hash data.
 */
#pragma once
#include <picofuse/sys.h>

/**
 * @brief Algorithms which hash data.
 * @ingroup Foundation
 *
 * MD5 isn't secure, so it's only for uses such as checksums.
 *
 * \headerfile NXHashAlgorithm.h Foundation/Foundation.h
 */
typedef enum {
  NXHashAlgorithmMD5 = sys_hash_md5,       ///< MD5, which is 16 bytes
  NXHashAlgorithmSHA256 = sys_hash_sha256, ///< SHA-256, which is 32 bytes
} NXHashAlgorithm;

/**
 * @brief The size in bytes of the largest hash.
 * @ingroup Foundation
 */
#define NXHashMaxSize SYS_HASH_SIZE
