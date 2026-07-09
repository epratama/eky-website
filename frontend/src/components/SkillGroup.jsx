import { useScrollReveal } from '../hooks/useScrollReveal'

export default function SkillGroup({ group, index }) {
  const { ref, isVisible } = useScrollReveal()

  return (
    <div
      ref={ref}
      className={`border-[3px] border-brutal-primary bg-white p-5 hover:shadow-brutal-lg transition-shadow duration-200 cursor-pointer ${
        isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-6'
      }`}
      style={{ transitionDelay: `${index * 60}ms` }}
    >
      <h3 className="font-heading text-sm font-extrabold text-brutal-accent uppercase tracking-wider mb-3">
        {group.category}
      </h3>
      <div className="flex flex-wrap gap-2">
        {group.items.map((item, i) => (
          <span
            key={i}
            className="inline-block border-[2px] border-brutal-primary px-2.5 py-1 font-body text-xs font-semibold text-brutal-primary hover:bg-brutal-primary hover:text-brutal-bg transition-colors duration-150 cursor-pointer"
          >
            {item}
          </span>
        ))}
      </div>
    </div>
  )
}
