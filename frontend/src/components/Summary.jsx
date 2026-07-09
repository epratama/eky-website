import SectionTitle from './SectionTitle'
import { useScrollReveal } from '../hooks/useScrollReveal'

export default function Summary({ summary }) {
  const { ref, isVisible } = useScrollReveal()

  return (
    <section id="summary" className="py-20 px-6">
      <div className="mx-auto max-w-4xl">
        <SectionTitle number="01" title="About" />

        <div
          ref={ref}
          className={`border-[3px] border-brutal-primary bg-white shadow-brutal p-6 md:p-10 transition-all duration-400 ${
            isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
          }`}
        >
          <div className="flex gap-6">
            <div className="hidden sm:block w-1.5 bg-brutal-accent flex-shrink-0" />
            <p className="font-body text-base md:text-lg leading-relaxed text-brutal-primary">
              {summary}
            </p>
          </div>
        </div>
      </div>
    </section>
  )
}
