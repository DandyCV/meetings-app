# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

user = User.find_or_create_by!(email: "demo@example.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

meetings = [
  { title: "Sprint planning", description: "Plan the upcoming sprint backlog.", starts_at: 2.days.from_now },
  { title: "Design review", description: "Review the new onboarding flow mockups.", starts_at: 5.days.from_now },
  { title: "1:1 with manager", description: "Monthly check-in.", starts_at: 1.week.from_now },
  { title: "Retro", description: "Sprint retrospective.", starts_at: 2.days.ago },
  { title: "All-hands", description: "Company-wide update meeting.", starts_at: 1.week.ago }
]

meetings.each do |attrs|
  user.meetings.find_or_create_by!(title: attrs[:title]) do |meeting|
    meeting.description = attrs[:description]
    meeting.starts_at = attrs[:starts_at]
  end
end
