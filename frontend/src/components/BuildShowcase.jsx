import { Github } from 'lucide-react'
import SectionTitle from './SectionTitle'
import { useScrollReveal } from '../hooks/useScrollReveal'

export default function BuildShowcase({ repo }) {
  const { ref, isVisible } = useScrollReveal()

  return (
    <section id="showcase" className="py-20 px-6">
      <div className="mx-auto max-w-4xl">
        <SectionTitle number="07" title="How This Site Was Built" />

        <div
          ref={ref}
          className={`border-[3px] border-brutal-primary bg-white shadow-brutal p-6 md:p-10 transition-all duration-400 ${
            isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
          }`}
        >
          <div className="flex flex-col sm:flex-row items-start gap-6">
            <div className="hidden sm:block w-1.5 bg-brutal-accent flex-shrink-0 self-stretch" />
            <div className="flex flex-col gap-4">
              <p className="font-body text-lg md:text-xl font-medium text-brutal-primary">
                Want to know how this site was built?
              </p>
              <a
                href={repo}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 border-[3px] border-brutal-primary px-5 py-2.5 font-body font-bold text-sm text-brutal-primary hover:bg-brutal-primary hover:text-brutal-bg cursor-pointer transition-colors duration-150"
              >
                <Github size={18} />
                See the code on GitHub →
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
