import { useScrollReveal } from '../hooks/useScrollReveal'

export default function SectionTitle({ number, title }) {
  const { ref, isVisible } = useScrollReveal()

  return (
    <div
      ref={ref}
      className={`mb-10 flex items-end gap-4 transition-all duration-400 ${
        isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'
      }`}
    >
      <span className="font-mono text-6xl font-medium text-brutal-accent leading-none">
        {number}
      </span>
      <h2 className="font-heading text-3xl md:text-4xl font-extrabold text-brutal-primary leading-none pb-1">
        {title}
      </h2>
      <div className="flex-1 border-b-[3px] border-brutal-primary mb-1.5 ml-2 hidden sm:block" />
    </div>
  )
}
