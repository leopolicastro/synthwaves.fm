export function buildTrackFromElement(el) {
  const d = el.dataset

  const track = {
    trackId: parseInt(d.songRowTrackIdValue) || 0,
    title: d.songRowTitleValue || "",
    artist: d.songRowArtistValue || ""
  }

  if (d.songRowAlbumTitleValue) {
    track.albumTitle = d.songRowAlbumTitleValue
  }

  if (d.songRowDurationValue) {
    track.duration = parseInt(d.songRowDurationValue)
  }

  if (d.songRowIsLiveValue === "true") {
    track.isLive = true
  }

  if (d.songRowCoverUrlValue) {
    track.coverUrl = d.songRowCoverUrlValue
  }

  if (d.songRowIsPodcastValue === "true") {
    track.isPodcast = true
  }

  if (d.songRowStreamUrlValue) {
    track.streamUrl = d.songRowStreamUrlValue
  }
  if (d.songRowYoutubeVideoIdValue) {
    track.youtubeVideoId = d.songRowYoutubeVideoIdValue
  }

  if (d.songRowNativeStreamUrlValue) {
    track.nativeStreamUrl = d.songRowNativeStreamUrlValue
  }

  if (d.songRowNativeCoverArtUrlValue) {
    track.nativeCoverArtUrl = d.songRowNativeCoverArtUrlValue
  }

  return track
}
