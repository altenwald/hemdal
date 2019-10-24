defmodule Hemdal do
  @moduledoc """
  Hemdal is a system for Alert/Alarm very customizable. It's based on
  [Nagios](https://www.nagios.com) where you have different scripts to check
  the status of different elements of your system providing back information
  about these checks.

  ## Motivation

  The problem with other systems like Nagios, Icinga or Sensu is they are
  based on the client/server infrastructure and requires to install an agent
  inside of each remote node. Hemdal works in the opposite way. Hemdal
  requires to configure an SSH access to the server to be monitorized, which
  could be even configured using a ssh proxy tunnel, transfer there the
  needed scripts (if needed) or run the specific commands and gather the
  responses.

  ## Connection to Monitored Services

  The connections to the other node are handled in a very controlled way.
  You can define how many connections are supported at the same time, and the
  frequency of the tests made. For example, you can check every minute or every
  30 seconds a very important service but only once a week or once a day the
  SSL certificate expiration date.

  ## The power of BEAM

  This system is built on top of BEAM. That let us to handle each
  alert inside of a different process and even spread in different nodes.
  Each alert is indeed a state machine which have perfect control of the checks
  the result and what is going to do in the following steps according to the
  results.

  Of course, everything is reloaded without stopping the system. We can add new
  hosts, change configuration for these hosts and change alerts, notifications,
  timers, everything. It's reloaded immediately and applied when it's secure to
  be applied.

  ## Everything is an event

  The internal system is based on event broadcasting. There is a producer which
  generates events from check processes and these are broadcasted to all of the
  event consumers: channels (for web real-time monitoring), logger (for
  database storage) and notif (to send it via Slack and in near future other
  notification providers).

  ## Database, why?

  Becase we need persistence and databases are great for that. But the database
  in this case isn't strongly used. The information from database is requested
  only at beginning and when a `reload` command is performed.

  Of course, the main role of the database is store also the logs for the changes
  of the alerts/alarms. Just in case you need to restart the system, we can gather
  the information about the alerts from the database and start rechecking again.

  ## Clustering

  The main focus for this system is scalability. And make it as easy as possible.
  It's still a work in progress but using [Horde](https://github.com/derekkraan/horde)
  we can achieve to distribute the check processes through all of the nodes you
  have connected in a BEAM way.

  ## Further information

  Check our guides to get more information about some specific points.
  """

  def reload_all do
    Hemdal.Host.Conn.reload_all
    Hemdal.Check.reload_all
  end
end
