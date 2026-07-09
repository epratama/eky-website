export default function DecorativeShapes() {
  return (
    <svg
      viewBox="0 0 300 300"
      className="w-full max-w-[300px] h-auto text-brutal-accent"
      fill="none"
      aria-hidden="true"
    >
      <circle cx="40" cy="40" r="8" fill="currentColor" />
      <rect x="120" y="20" width="40" height="40" stroke="currentColor" strokeWidth="3" />
      <circle cx="260" cy="100" r="12" fill="currentColor" opacity="0.7" />
      <path
        d="M20 160 Q60 140 100 160 Q140 180 180 160 Q220 140 260 160"
        stroke="currentColor"
        strokeWidth="3"
        strokeLinecap="round"
      />
      <rect x="60" y="220" width="30" height="30" fill="currentColor" opacity="0.5" />
      <path
        d="M170 210 L190 230 L210 210"
        stroke="currentColor"
        strokeWidth="3"
        strokeLinejoin="round"
      />
      <circle cx="250" cy="250" r="16" stroke="currentColor" strokeWidth="3" />
    </svg>
  )
}
