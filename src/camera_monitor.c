/**
 * @file camera_monitor.c
 * @brief Camera monitoring with human detection and greeting
 *
 * This module implements camera-based human detection using AI vision.
 * When a person is detected, it automatically plays a greeting message.
 *
 * @copyright Copyright (c) 2021-2025 Tuya Inc. All Rights Reserved.
 */

#include "tal_api.h"
#include "ai_video_input.h"
#include "ai_agent.h"
#include "ai_audio_player.h"
#include "ducky_claw_chat.h"

/***********************************************************
************************macro define************************
***********************************************************/
#define MONITOR_CHECK_INTERVAL_MS   5000    // Check every 5 seconds
#define PERSON_DETECT_COOLDOWN_MS   15000   // Greeting cooldown (15 seconds)
#define DETECT_IMAGE_MAX_SIZE       (30*1024) // Max image size 30KB

/***********************************************************
***********************typedef define***********************/
typedef enum {
    MONITOR_STATE_IDLE = 0,
    MONITOR_STATE_CAPTURING,
    MONITOR_STATE_ANALYZING,
    MONITOR_STATE_GREETING,
} MONITOR_STATE_E;

/***********************************************************
***********************variable define**********************/
static TIMER_ID       sg_monitor_timer = NULL;
static MUTEX_HANDLE   sg_monitor_mutex = NULL;
static MONITOR_STATE_E sg_monitor_state = MONITOR_STATE_IDLE;
static uint64_t       sg_last_greeting_time = 0;
static bool           sg_monitor_enabled = false;

// Greeting messages
static const char *greeting_messages[] = {
    "你好！很高兴见到你！",
    "欢迎！有什么可以帮助您的吗？",
    "您好！我是您的智能助手！",
    "欢迎光临！请问需要什么帮助？",
    "您好！我随时准备为您服务！"
};

/***********************************************************
***********************function define**********************/

/**
 * @brief Get random greeting message
 */
static const char* __get_random_greeting(void)
{
    uint32_t count = sizeof(greeting_messages) / sizeof(greeting_messages[0]);
    uint32_t index = tal_system_get_random(count);
    return greeting_messages[index];
}

/**
 * @brief Check if enough time has passed since last greeting
 */
static bool __can_greet(void)
{
    uint64_t current_time = tal_system_get_millisecond();
    if ((current_time - sg_last_greeting_time) > PERSON_DETECT_COOLDOWN_MS) {
        return true;
    }
    return false;
}

/**
 * @brief Play greeting using AI TTS
 */
static void __play_greeting(void)
{
    const char *greeting = __get_random_greeting();

    PR_INFO("Playing greeting: %s", greeting);

    // Send greeting text to AI agent for TTS playback
    OPERATE_RET rt = ai_agent_send_text((char *)greeting);
    if (rt != OPRT_OK) {
        PR_ERR("Failed to send greeting: %d", rt);
        // Fallback to alert sound if TTS fails
        ai_audio_player_alert(AI_AUDIO_ALERT_WAKEUP);
    }

    sg_last_greeting_time = tal_system_get_millisecond();
}

/**
 * @brief Analyze image for human detection using AI
 * This sends the image to AI agent for analysis
 */
static void __analyze_image_for_human(uint8_t *image_data, uint32_t image_len)
{
    PR_INFO("Analyzing image for human detection, size: %d bytes", image_len);

    // Send image to AI agent
    // The AI will analyze the image and respond if a person is detected
    OPERATE_RET rt = ai_agent_send_image(image_data, image_len);
    if (rt != OPRT_OK) {
        PR_ERR("Failed to send image for analysis: %d", rt);
    }
}

/**
 * @brief Monitor timer callback - Periodic check
 */
static void __monitor_timer_cb(TIMER_ID timer_id, void *arg)
{
    (void)timer_id;
    (void)arg;

    if (!sg_monitor_enabled) {
        return;
    }

    tal_mutex_lock(sg_monitor_mutex);

    if (sg_monitor_state != MONITOR_STATE_IDLE) {
        PR_DEBUG("Monitor busy, current state: %d", sg_monitor_state);
        tal_mutex_unlock(sg_monitor_mutex);
        return;
    }

    sg_monitor_state = MONITOR_STATE_CAPTURING;
    tal_mutex_unlock(sg_monitor_mutex);

    // Capture image from camera
    uint8_t *image_data = NULL;
    uint32_t image_len = 0;

    PR_DEBUG("Capturing image for human detection...");

    OPERATE_RET rt = ai_video_get_jpeg_frame(&image_data, &image_len);
    if (rt != OPRT_OK || image_data == NULL || image_len == 0) {
        PR_ERR("Failed to capture image: %d", rt);
        tal_mutex_lock(sg_monitor_mutex);
        sg_monitor_state = MONITOR_STATE_IDLE;
        tal_mutex_unlock(sg_monitor_mutex);
        return;
    }

    PR_INFO("Image captured: %d bytes", image_len);

    // Check image size limit
    if (image_len > DETECT_IMAGE_MAX_SIZE) {
        PR_WARN("Image too large: %d bytes, skipping analysis", image_len);
        ai_video_jpeg_image_free(&image_data);
        tal_mutex_lock(sg_monitor_mutex);
        sg_monitor_state = MONITOR_STATE_IDLE;
        tal_mutex_unlock(sg_monitor_mutex);
        return;
    }

    tal_mutex_lock(sg_monitor_mutex);
    sg_monitor_state = MONITOR_STATE_ANALYZING;
    tal_mutex_unlock(sg_monitor_mutex);

    // Analyze image
    __analyze_image_for_human(image_data, image_len);

    // Free image data
    ai_video_jpeg_image_free(&image_data);

    tal_mutex_lock(sg_monitor_mutex);
    sg_monitor_state = MONITOR_STATE_IDLE;
    tal_mutex_unlock(sg_monitor_mutex);
}

/**
 * @brief Handle AI response for human detection
 * This is called when AI responds after analyzing the image
 */
void camera_monitor_handle_ai_response(const char *response)
{
    if (!sg_monitor_enabled) {
        return;
    }

    if (response == NULL) {
        return;
    }

    PR_INFO("AI response: %s", response);

    // Check if AI detected a person in the image
    // AI should respond with something like "检测到有人" or "有人"
    if ((strstr(response, "人") != NULL || strstr(response, "person") != NULL ||
         strstr(response, "human") != NULL || strstr(response, "有人") != NULL)) {

        PR_NOTICE("Person detected!");

        if (__can_greet()) {
            __play_greeting();
        } else {
            PR_DEBUG("Greeting on cooldown");
        }
    }
}

/**
 * @brief Initialize camera monitoring module
 */
OPERATE_RET camera_monitor_init(void)
{
    OPERATE_RET rt = OPRT_OK;

    PR_NOTICE("Initializing camera monitor...");

    // Create mutex
    rt = tal_mutex_create_init(&sg_monitor_mutex);
    if (rt != OPRT_OK) {
        PR_ERR("Failed to create mutex: %d", rt);
        return rt;
    }

    // Create timer for periodic checking
    rt = tal_sw_timer_create(__monitor_timer_cb, NULL, &sg_monitor_timer);
    if (rt != OPRT_OK) {
        PR_ERR("Failed to create timer: %d", rt);
        tal_mutex_release(sg_monitor_mutex);
        sg_monitor_mutex = NULL;
        return rt;
    }

    sg_monitor_enabled = false;
    sg_monitor_state = MONITOR_STATE_IDLE;
    sg_last_greeting_time = 0;

    PR_NOTICE("Camera monitor initialized successfully");

    return OPRT_OK;
}

/**
 * @brief Start camera monitoring
 */
OPERATE_RET camera_monitor_start(void)
{
    if (sg_monitor_timer == NULL) {
        PR_ERR("Monitor not initialized");
        return OPRT_COM_ERROR;
    }

    PR_NOTICE("Starting camera monitor...");

    sg_monitor_enabled = true;

    // Start periodic timer
    tal_sw_timer_start(sg_monitor_timer, MONITOR_CHECK_INTERVAL_MS, TAL_TIMER_CYCLE);

    PR_NOTICE("Camera monitor started, checking every %d ms", MONITOR_CHECK_INTERVAL_MS);

    return OPRT_OK;
}

/**
 * @brief Stop camera monitoring
 */
OPERATE_RET camera_monitor_stop(void)
{
    PR_NOTICE("Stopping camera monitor...");

    sg_monitor_enabled = false;

    if (sg_monitor_timer != NULL) {
        tal_sw_timer_stop(sg_monitor_timer);
    }

    tal_mutex_lock(sg_monitor_mutex);
    sg_monitor_state = MONITOR_STATE_IDLE;
    tal_mutex_unlock(sg_monitor_mutex);

    return OPRT_OK;
}

/**
 * @brief Deinitialize camera monitoring
 */
OPERATE_RET camera_monitor_deinit(void)
{
    PR_NOTICE("Deinitializing camera monitor...");

    camera_monitor_stop();

    if (sg_monitor_timer != NULL) {
        tal_sw_timer_stop(sg_monitor_timer);
        tal_sw_timer_release();
        sg_monitor_timer = NULL;
    }

    if (sg_monitor_mutex != NULL) {
        tal_mutex_release(sg_monitor_mutex);
        sg_monitor_mutex = NULL;
    }

    return OPRT_OK;
}

/**
 * @brief Check if monitoring is enabled
 */
bool camera_monitor_is_enabled(void)
{
    return sg_monitor_enabled;
}
