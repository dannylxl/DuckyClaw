/**
 * @file camera_monitor.h
 * @brief Camera monitoring with human detection and greeting
 *
 * This module implements camera-based human detection using AI vision.
 * When a person is detected, it automatically plays a greeting message.
 *
 * @copyright Copyright (c) 2021-2025 Tuya Inc. All Rights Reserved.
 */

#ifndef __CAMERA_MONITOR_H__
#define __CAMERA_MONITOR_H__

#include "tal_api.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialize camera monitoring module
 *
 * @return OPRT_OK on success, error code otherwise
 */
OPERATE_RET camera_monitor_init(void);

/**
 * @brief Start camera monitoring
 *
 * Starts the periodic timer to capture and analyze images.
 *
 * @return OPRT_OK on success, error code otherwise
 */
OPERATE_RET camera_monitor_start(void);

/**
 * @brief Stop camera monitoring
 *
 * Stops the periodic timer.
 *
 * @return OPRT_OK on success, error code otherwise
 */
OPERATE_RET camera_monitor_stop(void);

/**
 * @brief Deinitialize camera monitoring
 *
 * Releases all resources.
 *
 * @return OPRT_OK on success, error code otherwise
 */
OPERATE_RET camera_monitor_deinit(void);

/**
 * @brief Check if monitoring is enabled
 *
 * @return true if monitoring is enabled, false otherwise
 */
bool camera_monitor_is_enabled(void);

/**
 * @brief Handle AI response for human detection
 *
 * This is called when AI responds after analyzing the image.
 *
 * @param response AI response text
 */
void camera_monitor_handle_ai_response(const char *response);

#ifdef __cplusplus
}
#endif

#endif /* __CAMERA_MONITOR_H__ */
