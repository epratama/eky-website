import SectionTitle from './SectionTitle'
import SkillGroup from './SkillGroup'

export default function Skills({ skills }) {
  return (
    <section id="skills" className="py-20 px-6 bg-white border-y-[3px] border-brutal-primary">
      <div className="mx-auto max-w-6xl">
        <SectionTitle number="04" title="Skills" />

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {skills.map((group, i) => (
            <SkillGroup key={i} group={group} index={i} />
          ))}
        </div>
      </div>
    </section>
  )
}
