import { useScrollReveal } from '../hooks/useScrollReveal'

export default function AchievementCard({ achievement, index }) {
  const { ref, isVisible } = useScrollReveal()

  const delay = `${index * 80}ms`

  return (
    <div
      ref={ref}
      className={`border-[3px] border-brutal-primary bg-white shadow-brutal p-6 hover:shadow-brutal-lg transition-all duration-200 ${
        isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'
      }`}
      style={{ transitionDelay: delay }}
    >
      <span className="font-heading text-4xl font-extrabold text-brutal-accent leading-none">
        {String(index + 1).padStart(2, '0')}
      </span>
      <h3 className="font-heading text-lg font-bold text-brutal-primary mt-3 mb-2">
        {achievement.title}
      </h3>
      <p className="font-body text-sm text-brutal-muted leading-relaxed">
        {achievement.description}
      </p>
    </div>
  )
}
