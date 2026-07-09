import SectionTitle from './SectionTitle'
import ExperienceCard from './ExperienceCard'

export default function Experience({ experience }) {
  return (
    <section id="experience" className="py-20 px-6">
      <div className="mx-auto max-w-3xl">
        <SectionTitle number="03" title="Experience" />

        <div className="border-l-[3px] border-brutal-primary ml-2 md:ml-3">
          {experience.map((role, i) => (
            <ExperienceCard key={i} role={role} />
          ))}
        </div>
      </div>
    </section>
  )
}
