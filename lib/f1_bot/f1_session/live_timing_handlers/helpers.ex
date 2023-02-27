defmodule F1Bot.F1Session.LiveTimingHandlers.Helpers do
  require Logger
  alias F1Bot.F1Session.LiveTimingHandlers.ProcessingOptions

  @log_dir "tmp"

  def maybe_log_driver_data(label, driver_number, data, options = %ProcessingOptions{}) do
    if options.log_drivers != nil and driver_number in options.log_drivers do
      data_fmt = inspect(data, limit: :infinity)
      line = "#{label} for ##{driver_number}: #{data_fmt}"

      Logger.info(line)

      File.mkdir_p(@log_dir)
      path = Path.join([@log_dir, "car_#{driver_number}.txt"])
      File.write(path, [line, "\n"], [:append])
    end
  end
end
