import { useScrollReveal } from '../hooks/useScrollReveal'
import DecorativeShapes from './DecorativeShapes'
import { Linkedin } from 'lucide-react'

export default function Hero({ data }) {
  const { ref, isVisible } = useScrollReveal()

  return (
    <section
      id="hero"
      className="min-h-screen pt-24 pb-16 px-6 flex items-center"
    >
      <div
        ref={ref}
        className={`mx-auto w-full max-w-6xl grid md:grid-cols-[1fr_auto] gap-10 items-center transition-all duration-500 ${
          isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'
        }`}
      >
        <div className="space-y-6 md:-translate-x-4">
          <div className="inline-block border-[3px] border-brutal-accent px-4 py-1">
            <span className="font-mono text-sm font-medium text-brutal-accent">
              {data.title}
            </span>
          </div>

          <h1 className="font-heading text-5xl sm:text-6xl md:text-7xl lg:text-8xl font-extrabold text-brutal-primary leading-[0.95]">
            {data.name.split(' ')[0]}
            <br />
            {data.name.split(' ')[1]}
          </h1>

          <p className="font-mono text-sm text-brutal-muted">
            {data.location}
          </p>

          <a
            href={data.linkedin}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 border-[3px] border-brutal-primary px-5 py-2.5 font-body font-bold text-sm text-brutal-primary hover:bg-brutal-primary hover:text-brutal-bg cursor-pointer transition-colors duration-150"
          >
            <Linkedin size={18} />
            LinkedIn
          </a>
        </div>

        <div className="hidden md:block">
          <DecorativeShapes />
        </div>
      </div>
    </section>
  )
}
