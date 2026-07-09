import SectionTitle from './SectionTitle'
import AchievementCard from './AchievementCard'

export default function KeyAchievements({ achievements }) {
  return (
    <section id="achievements" className="py-20 px-6 bg-white border-y-[3px] border-brutal-primary">
      <div className="mx-auto max-w-6xl">
        <SectionTitle number="02" title="Key Achievements" />

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {achievements.map((achievement, i) => (
            <AchievementCard key={i} achievement={achievement} index={i} />
          ))}
        </div>
      </div>
    </section>
  )
}
