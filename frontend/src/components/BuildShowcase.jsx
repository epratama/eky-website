import { Github } from 'lucide-react'
import SectionTitle from './SectionTitle'
import { useScrollReveal } from '../hooks/useScrollReveal'

export default function BuildShowcase({ repo }) {
  const { ref, isVisible } = useScrollReveal()

  return (
    <section id="showcase" className="py-20 px-6">
      <div className="mx-auto max-w-4xl">
        <SectionTitle number="05" title="How This Site Was Built" />

        <div
          ref={ref}
          className={`border-[3px] border-brutal-primary bg-white shadow-brutal p-6 md:p-10 transition-all duration-400 ${
            isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
          }`}
        >
          <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-3">
              <p className="font-body text-base md:text-lg font-medium text-brutal-primary leading-relaxed">
                Built through <span className="font-bold text-brutal-accent">Multi-Agent AI Orchestration</span> — with production engineering and security standards.
              </p>
              <p className="font-body text-sm text-brutal-muted">
                See how it's done →
              </p>
            </div>
            <a
              href={repo}
              target="_blank"
              rel="noopener noreferrer"
              className={`inline-flex items-center gap-2 border-[3px] border-brutal-primary px-5 py-2.5 font-body font-bold text-sm text-brutal-primary hover:bg-brutal-primary hover:text-brutal-bg cursor-pointer transition-all duration-200 ${isVisible ? 'animate-glow-ring' : ''}`}
            >
              <Github size={18} />
              See the code on GitHub →
            </a>
          </div>
        </div>
      </div>
    </section>
  )
}
