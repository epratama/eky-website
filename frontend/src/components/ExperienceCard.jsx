import { useState } from 'react'
import { useScrollReveal } from '../hooks/useScrollReveal'
import { ChevronDown, ChevronUp } from 'lucide-react'

export default function ExperienceCard({ role }) {
  const [expanded, setExpanded] = useState(false)
  const { ref, isVisible } = useScrollReveal()

  return (
    <div
      ref={ref}
      className={`relative pl-8 md:pl-12 transition-all duration-400 ${
        isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
      }`}
    >
      <div className="absolute -left-2 top-1 w-4 h-4 border-[3px] border-brutal-accent bg-brutal-accent rounded-full" />

      <div className="border-[3px] border-brutal-primary bg-white shadow-brutal p-5 md:p-7 mb-10 hover:shadow-brutal-lg transition-shadow duration-200">
        <div className="flex flex-col sm:flex-row sm:items-baseline sm:justify-between gap-1 mb-2">
          <h3 className="font-heading text-xl font-extrabold text-brutal-primary">
            {role.role}
          </h3>
          <span className="font-mono text-xs font-medium text-brutal-muted whitespace-nowrap">
            {role.period}
          </span>
        </div>

        <p className="font-heading text-base font-bold text-brutal-accent mb-3">
          {role.company}
        </p>
        <p className="font-mono text-xs text-brutal-muted mb-3">
          {role.location}
        </p>
        <p className="font-body text-sm text-brutal-muted mb-4 leading-relaxed">
          {role.description}
        </p>

        <button
          onClick={() => setExpanded(!expanded)}
          className="flex items-center gap-1 font-body text-sm font-bold text-brutal-accent hover:text-brutal-primary cursor-pointer transition-colors duration-150"
          aria-expanded={expanded}
        >
          {expanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
          {expanded ? 'Show less' : `Show highlights (${role.highlights?.length ?? 0})`}
        </button>

        {expanded && (
          <ul className="mt-4 space-y-2 border-t-[3px] border-brutal-primary pt-4">
            {role.highlights?.map((item, i) => (
              <li
                key={i}
                className="font-body text-sm text-brutal-primary leading-relaxed pl-4 relative before:content-['—'] before:absolute before:left-0 before:text-brutal-accent before:font-mono"
              >
                {item}
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}
