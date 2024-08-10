require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end

end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end

end

def clean_phone_numbers(number)
  if number.length < 10 || (number.length > 10 && number[0] != '1')
    "If you would like to receive mobile alerts, reply to this mail with you home phone number."
  else
    "We are going to be sending you mobile alerts to the number #{number[0..9]}. To cancel the service you may reply to the SMS with NO"
  end
end

def get_time_targeting(date, table)
  date = Time.strptime(date, '%m/%d/%y %H:%M')
  table[date.hour] += 1
end

def get_weekday_targeting(date, table)
  date = Time.strptime(date, '%m/%d/%y %H:%M')
  date = Date.new(date.year, date.month, date.day)
  week_num_to_str = {
      0 => "Sun",
      1 => "Mon",
      2 => "Tue",
      3 => "Wed",
      4 => "Thu",
      5 => "Fri",
      6 => "Sat"
  }
  table[week_num_to_str[date.wday]] += 1
end

puts 'EventManager Initialized!'

contents = CSV.open(
  'event_attendees.csv', 
   headers: true, 
   header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

hours_registered = {}

for i in 0..23 do
  hours_registered[i] = 0
end

weekday_registered = {}

for i in ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] do
  weekday_registered[i] = 0
end

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  phoneMessage = clean_phone_numbers(row[5])

  form_letter = erb_template.result(binding)

  get_time_targeting(row[1], hours_registered)

  get_weekday_targeting(row[1], weekday_registered)
  
  save_thank_you_letter(id, form_letter)

end

puts "Statisitcs: \n Hours: #{hours_registered}; \n Weekdays: #{weekday_registered};"
