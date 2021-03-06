
require 'rubygems'
require 'nokogiri'
require 'open-uri'

module PI

## 这个代表某个时点的测试快照
class Snapshot
  attr_accessor :time, :version, :hour, :status, :code_change, :code_changed_by, :scp_change, :scp_changed_by, :mstest_failures, :selenium_failures, :deployment_status, :apaclocal_changed_by

  SOURCE_URL_GLOBAL = "http://pi.careerbuilder.com/web/teamportal"
  SOURCE_URL_APAC = "http://pi.careerbuilder.com/web/TeamPortal/APACLocal"

  MAX_COUNT_OF_SNAPSHOT = 12

  def initialize(tr_node_inner_html, date)
    td_node_contents = []

    tr_node_inner_html.css('td').each do |td_node|
      td_node_contents << td_node.content.gsub(/\s+/,'')
    end

    @time = get_time(date, td_node_contents[1].to_i)
    @version = td_node_contents[0]
    @hour = td_node_contents[1]
    @status = td_node_contents[2]
    @code_change = td_node_contents[3]
    @code_changed_by = PI::CodeChange.new(get_formatted_date_str(date), @hour, @version).modified_by
    @scp_change = td_node_contents[4]
    @scp_changed_by = PI::SCPChange.new(get_formatted_date_str(date), @hour, @version).modified_by
    @mstest_failures = td_node_contents[5]
    @selenium_failures = td_node_contents[6]
    @deployment_status = td_node_contents[7]
    @apaclocal_changed_by = get_apaclocal_changed_by(@scp_changed_by, @code_changed_by)
  end



  def self.get_current_snapshots(source)
    snapshots = []
    count_of_snapshot = 0

    table_inner_html = Nokogiri::HTML(get_table_content(source))

    table_inner_html.css("tr").each do  |tr_node|
      if(is_table_head_row?(tr_node.inner_html))
        next
      end

      if(is_date_row?(tr_node.inner_html))
        @time = Time.parse(tr_node.content)
        next
      end

      snapshots << Snapshot.new(Nokogiri::HTML(tr_node.inner_html), @time)

      count_of_snapshot += 1
      break if count_of_snapshot >= MAX_COUNT_OF_SNAPSHOT
    end

    return snapshots
  end

  def self.is_table_head_row?(node_content)
    return node_content.include? "th"
  end

  def self.is_date_row?(node_content)
    return node_content.include? ","
  end

  def self.get_table_content(source)
    page = Nokogiri::HTML(open(source))
    return page.css('table.team-hourly-metrics-table').inner_html
  end

  def is_pending?
    return (selenium_failures == 'Pending')
  end

  def get_status_text
    if(is_pending?)
      return ": |"
    end

    if(status == "success")
      return ": )"
    else
      return ": ("
    end
  end

  def has_failure_or_notrun?
    return !((mstest_failures == "0") && (selenium_failures == "0"))
  end

  def code_changed_by_apaclocal?
    code_changed_by.each do |item|
      if (PI::Change::MEMBER_OF_APACLOCAL.include?(item)) then
        return true
      end
    end

    return false
  end

  def scp_changed_by_apaclocal?
    scp_changed_by.each do |item|
      if (PI::Change::MEMBER_OF_APACLOCAL.include?(item)) then
        return true
      end
    end

    return false
  end

  def to_s
    return "#{@time}, version #{@version} get #{@status} result, mstest failure(#{@mstest_failures}), selenium failure(#{@selenium_failures}); code change(#{@code_change}), SCP change(#{@scp_change})"
  end



private

  def get_apaclocal_changed_by(scp_changed_by, code_changed_by)
    result = []

    if(!scp_changed_by.nil?)
      scp_changed_by.each do |item|
        if (PI::Change::MEMBER_OF_APACLOCAL.include?(item) && (!result.include?(item))) then
          result << item
        end
      end
    end

    if(!code_changed_by.nil?)
      code_changed_by.each do |item|
        if (PI::Change::MEMBER_OF_APACLOCAL.include?(item) && (!result.include?(item))) then
          result << item
        end
      end
    end

    return result
  end

  def get_time(date, hour)
    return (date + (hour * 60 * 60)).strftime("%Y-%m-%d %H:00")
  end

  def get_formatted_date_str(date)
    date.strftime('%m/%d/%Y').to_s
  end

end

end
