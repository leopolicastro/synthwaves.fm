module IPTVChannelsHelper
  PIXELS_PER_MINUTE = 7

  def guide_grid_width(window_start, window_end)
    minutes = ((window_end - window_start) / 60).to_i
    minutes * PIXELS_PER_MINUTE
  end

  def programme_left_px(programme, window_start)
    starts = programme.respond_to?(:starts_at) ? programme.starts_at : programme
    effective_start = [starts, window_start].max
    minutes_from_start = ((effective_start - window_start) / 60).to_f
    (minutes_from_start * PIXELS_PER_MINUTE).round
  end

  def time_slot_left_px(time, window_start)
    minutes_from_start = ((time - window_start) / 60).to_f
    (minutes_from_start * PIXELS_PER_MINUTE).round
  end

  def programme_width_px(programme, window_start, window_end)
    effective_start = [programme.starts_at, window_start].max
    effective_end = [programme.ends_at, window_end].min
    duration_minutes = ((effective_end - effective_start) / 60).to_f
    (duration_minutes * PIXELS_PER_MINUTE).round
  end

  def guide_time_slots(window_start, window_end)
    slots = []
    current = window_start
    while current < window_end
      slots << current
      current += 30.minutes
    end
    slots
  end

  def retro_tv_channels_json(channels, programmes_by_channel)
    channels.map do |channel|
      programmes = programmes_by_channel[channel.tvg_id] || []
      {
        name: channel.name,
        streamUrl: channel.stream_url,
        logoUrl: channel.logo_url,
        programmes: programmes.map { |p|
          {title: p.title, subtitle: p.subtitle, startsAt: p.starts_at.to_i, endsAt: p.ends_at.to_i}
        }
      }
    end.to_json
  end
end
