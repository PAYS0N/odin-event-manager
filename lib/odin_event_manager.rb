# frozen_string_literal: true

require "csv"
require "google/apis/civicinfo_v2"
require "erb"

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def clean_phone(phone)
  phone = phone.gsub(/\D/, "")
  if phone.length == 10
    phone
  elsif phone.length == 11 && phone[0] == "1"
    phone[1...11]
  else
    "0000000000"
  end
end

def organize_times(str_times, times)
  date, time = str_times.split
  month, day, year = date.split("/")
  hours, minutes = time.split(":")
  time = Time.new(year, month, day, hours, minutes, 0)
  times[time.hour] += 1
end

def organize_days(str_times, times)
  date, time = str_times.split
  month, day, year = date.split("/")
  hours, minutes = time.split(":")
  time = Time.new(year, month, day, hours, minutes, 0)
  times[time.strftime("%A")] += 1
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = "AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw"

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: "country",
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id, form_letter)
  FileUtils.mkdir_p("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename, "w") do |file|
    file.puts form_letter
  end
end

def scoped_template(erb_template, name, legislators)
  erb_template.result(binding)
end

puts "EventManager initialized."

contents = CSV.open(
  "event_attendees.csv",
  headers: true,
  header_converters: :symbol
)

template_letter = File.read("form_letter.erb")
erb_template = ERB.new template_letter

times = Hash.new(0)
days = Hash.new(0)
contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phone(row[:homephone])
  organize_times(row[:regdate], times)
  organize_days(row[:regdate], days)
  legislators = legislators_by_zipcode(zipcode)

  form_letter = scoped_template(erb_template, name, legislators)

  puts "Phone: #{phone}"
  save_thank_you_letter(id, form_letter)
end

times.sort_by { |_, total| -total }.each do |hour, total|
  puts "Hour #{hour} had #{total} entries"
end
days.sort_by { |_, total| -total }.each do |day, total|
  puts "#{day} had #{total} entries"
end
