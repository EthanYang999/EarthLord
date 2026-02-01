-- Day 35: 修复 Realtime 位置序列化问题
-- 将 sender_location 从 GEOGRAPHY 改为 JSONB，确保 Realtime 能正确推送位置数据

-- 1. 修改 sender_location 列类型：GEOGRAPHY → JSONB
-- 先保留现有数据，将 PostGIS POINT 转换为 JSONB 格式
ALTER TABLE public.channel_messages
ALTER COLUMN sender_location TYPE JSONB
USING CASE
    WHEN sender_location IS NOT NULL THEN
        jsonb_build_object(
            'latitude', ST_Y(sender_location::geometry),
            'longitude', ST_X(sender_location::geometry)
        )
    ELSE NULL
END;

-- 2. 更新 send_channel_message 函数，直接存储 JSONB 格式的位置
CREATE OR REPLACE FUNCTION send_channel_message(
    p_channel_id UUID,
    p_content TEXT,
    p_latitude DOUBLE PRECISION DEFAULT NULL,
    p_longitude DOUBLE PRECISION DEFAULT NULL,
    p_device_type TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
    v_callsign TEXT;
    v_location JSONB;
    v_metadata JSONB;
    v_message_id UUID;
BEGIN
    -- 获取当前用户ID
    v_user_id := auth.uid();

    -- 验证用户已订阅该频道
    IF NOT EXISTS (
        SELECT 1 FROM public.channel_subscriptions
        WHERE channel_id = p_channel_id
        AND user_id = v_user_id
    ) THEN
        RAISE EXCEPTION '未订阅该频道';
    END IF;

    -- 获取用户呼号
    SELECT COALESCE(username, '匿名幸存者')
    INTO v_callsign
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_callsign IS NULL THEN
        v_callsign := '匿名幸存者';
    END IF;

    -- ✅ 创建 JSONB 格式的位置（而不是 PostGIS GEOGRAPHY）
    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        v_location := jsonb_build_object(
            'latitude', p_latitude,
            'longitude', p_longitude
        );
    END IF;

    -- 创建元数据
    v_metadata := jsonb_build_object('device_type', p_device_type);

    -- 插入消息（sender_location 现在是 JSONB 类型）
    INSERT INTO public.channel_messages (
        channel_id,
        sender_id,
        sender_callsign,
        content,
        sender_location,
        sender_device_type,
        metadata,
        created_at
    ) VALUES (
        p_channel_id,
        v_user_id,
        v_callsign,
        p_content,
        v_location,  -- ✅ JSONB 格式: {"latitude": 39.9, "longitude": 116.4}
        p_device_type,
        v_metadata,
        now()
    )
    RETURNING message_id INTO v_message_id;

    RETURN v_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION send_channel_message IS '发送频道消息 - 使用 JSONB 存储位置，确保 Realtime 兼容';
