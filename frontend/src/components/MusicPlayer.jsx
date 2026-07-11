import { useState, useRef, useEffect, useCallback } from 'react'
import { PlayCircle, PauseCircle, StopCircle, Loader2 } from 'lucide-react'
import SectionTitle from './SectionTitle'

const TRACK_URL =
  'https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F2093689164&color=%232563EB&auto_play=true&hide_related=true&show_comments=false&show_user=false&show_reposts=false&show_teaser=false'

const WIDGET_SCRIPT = 'https://w.soundcloud.com/player/api.js'

function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

export default function MusicPlayer() {
  const [state, setState] = useState('idle')
  const iframeRef = useRef(null)
  const widgetRef = useRef(null)
  const scriptRef = useRef(null)

  const statusText = {
    idle: 'Music player is idle',
    loading: 'Loading music',
    playing: 'Music is playing',
    paused: 'Music is paused',
    finished: 'Music has finished',
  }

  useEffect(() => {
    return () => {
      if (widgetRef.current) widgetRef.current.destroy()
      if (iframeRef.current && iframeRef.current.parentNode) {
        iframeRef.current.parentNode.removeChild(iframeRef.current)
      }
      if (scriptRef.current && scriptRef.current.parentNode) {
        scriptRef.current.parentNode.removeChild(scriptRef.current)
      }
    }
  }, [])

  const handlePlay = useCallback(() => {
    if (state === 'playing' || state === 'loading') return
    setState('loading')

    if (window.SC && widgetRef.current) {
      widgetRef.current.play()
      setState('playing')
      return
    }

    const script = document.createElement('script')
    script.src = WIDGET_SCRIPT
    script.async = true
    scriptRef.current = script

    script.onload = () => {
      if (!iframeRef.current) return

      const widget = window.SC.Widget(iframeRef.current)
      widgetRef.current = widget
      widget.bind(window.SC.Widget.Events.PLAY, () => setState('playing'))
      widget.bind(window.SC.Widget.Events.PAUSE, () => setState('paused'))
      widget.bind(window.SC.Widget.Events.FINISH, () => setState('finished'))
      widget.play()
      setState('playing')
    }

    script.onerror = () => {
      setState('idle')
      if (scriptRef.current && scriptRef.current.parentNode) {
        scriptRef.current.parentNode.removeChild(scriptRef.current)
      }
      scriptRef.current = null
    }

    document.head.appendChild(script)
  }, [state])

  const handlePause = useCallback(() => {
    if (widgetRef.current) {
      widgetRef.current.pause()
      setState('paused')
    }
  }, [])

  const handleStop = useCallback(() => {
    if (widgetRef.current) {
      widgetRef.current.stop()
      setState('idle')
    }
  }, [])

  const spinner = prefersReducedMotion() ? '' : 'animate-spin'

  return (
    <section
      role="region"
      aria-label="Music player"
      className="py-12 px-6 bg-white border-t-[3px] border-brutal-primary shadow-brutal"
    >
      <div className="mx-auto max-w-4xl flex flex-col items-center gap-4">
        <SectionTitle title="Listen While You Browse" />
        <iframe
          ref={iframeRef}
          title="SoundCloud music player"
          aria-hidden="true"
          src={TRACK_URL}
          width="1"
          height="1"
          className="absolute -left-[9999px] -top-[9999px]"
          referrerPolicy="no-referrer"
        />

        <div className="flex items-center gap-4">
          {state === 'loading' ? (
            <button
              aria-label="Loading"
              disabled
              className="flex items-center justify-center min-w-[48px] min-h-[48px] border-[3px] border-brutal-primary bg-brutal-primary text-brutal-bg cursor-not-allowed"
            >
              <Loader2 size={24} className={`w-6 h-6 ${spinner}`} />
            </button>
          ) : (
            <button
              aria-label={
                state === 'paused' || state === 'finished' || state === 'idle'
                  ? 'Play music'
                  : 'Pause music'
              }
              onClick={state === 'playing' ? handlePause : handlePlay}
              className="flex items-center justify-center min-w-[48px] min-h-[48px] border-[3px] border-brutal-primary bg-brutal-primary text-brutal-bg hover:bg-brutal-bg hover:text-brutal-primary cursor-pointer transition-colors duration-150"
            >
              {state === 'playing' ? (
                <PauseCircle size={24} className="w-6 h-6" />
              ) : (
                <PlayCircle size={24} className="w-6 h-6" />
              )}
            </button>
          )}

          {(state === 'playing' || state === 'paused') && (
            <button
              aria-label="Stop music"
              onClick={handleStop}
              className="flex items-center justify-center min-w-[48px] min-h-[48px] border-[3px] border-brutal-primary bg-white text-brutal-primary hover:bg-brutal-primary hover:text-brutal-bg cursor-pointer transition-colors duration-150"
            >
              <StopCircle size={24} className="w-6 h-6" />
            </button>
          )}
        </div>

        <p aria-live="polite" className="sr-only">
          {statusText[state]}
        </p>
      </div>
    </section>
  )
}
