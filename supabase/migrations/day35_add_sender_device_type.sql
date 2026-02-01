-- Day 35: Add sender_device_type column
-- 添加发送者设备类型字段，用于距离过滤

-- 1. 添加 sender_device_type 列
ALTER TABLE public.channel_messages
ADD COLUMN IF NOT EXISTS sender_device_type TEXT;

-- 2. 更新现有数据（从 metadata 中提取）
UPDATE public.channel_messages
SET sender_device_type = metadata->>'device_type'
WHERE metadata->>'device_type' IS NOT NULL;

-- 3. 修改 send_channel_message 函数，保存 sender_device_type
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
    v_location GEOGRAPHY(POINT, 4326);
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

    -- 创建位置点
    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        v_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::GEOGRAPHY;
    END IF;

    -- 创建元数据（保持向后兼容）
    v_metadata := jsonb_build_object('device_type', p_device_type);

    -- 插入消息（✅ 新增 sender_device_type 字段）
    INSERT INTO public.channel_messages (
        channel_id,
        sender_id,
        sender_callsign,
        content,
        sender_location,
        sender_device_type,
        metadata
    ) VALUES (
        p_channel_id,
        v_user_id,
        v_callsign,
        p_content,
        v_location,
        p_device_type,
        v_metadata
    )
    RETURNING message_id INTO v_message_id;

    RETURN v_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
