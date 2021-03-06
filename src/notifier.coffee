# Description:
#   Sends alert/invasion/news notifications to subscribed users
#
# Dependencies:
#   None
#
# Configuration:
#   MONGODB_URL - MongoDB url
#   HUBOT_LINE_END - Configuragble line-return character
#   HUBOT_BLOCK_END - Configuragble string for ending blocks
#   HUBOT_DOUBLE_RET - Configurable string for double-line returns
#
# Commands:
#   None
#
# Author:
#   nspacestd

util = require('util')
Users = require('./lib/users.js')
ds = require('./lib/deathsnacks.js')
platforms = require('./lib/platforms.json')

mongoURL = process.env.MONGODB_URL
NOTIFICATION_INTERVAL = 60 * 1000

module.exports = (robot) ->
  userDB = new Users(mongoURL)
  setInterval check, NOTIFICATION_INTERVAL, robot, userDB
  setTimeout check, 5000, robot, userDB

check = (robot, userDB) ->
  ###
  # Check for new alerts/invasions/news
  #
  # @param object robot
  # @param object userDB
  ###
  for platform in platforms
    checkAlerts(robot, userDB, platform)
    checkInvasions(robot, userDB, platform)
    checkNews(robot, userDB, platform)
  return

checkAlerts = (robot, userDB, platform) ->
  ###
  # Check for new alerts and notify them to subscribed users from userDB
  #
  # @param object robot
  # @param object userDB
  # @param string platform
  ###
  
  robot.logger.debug 'Checking alerts (' + platform + ')...'
  ds.getAlerts platform, (err, alerts) ->
    if err
      robot.logger.error err
    else
      # IDs are saved in robot.brain
      notifiedAlertIds = robot.brain.get('notifiedAlertIds' + platform) or []
      robot.brain.set 'notifiedAlertIds' + platform, (a.id for a in alerts)

      for a in alerts when a.id not in notifiedAlertIds
        types = a.getRewardTypes()

        # Credit only alerts are not notified
        if types.length
          query = $and: [
            {platform: platform}
            {items:
              $in: types
            }
            {items: 'alerts'}
          ]
          broadcast a.toString(), query, robot, userDB
      return

checkInvasions = (robot, userDB, platform) ->
  ###
  # Check for new invasions and notify them to subscribed users from userDB
  #
  # @param object robot
  # @param object userDB
  # @param string platform
  ###
  robot.logger.debug 'Checking invasions (' + platform + ')...'
  ds.getInvasions platform, (err, invasions) ->
    if err
      robot.logger.error err
    else
      # IDs are saved in robot.brain
      notifiedInvasionIds = robot.brain.get('notifiedInvasionIds' + platform) or []
      robot.brain.set 'notifiedInvasionIds' + platform, (i.id for i in invasions)

      for i in invasions when i.id not in notifiedInvasionIds
        types = i.getRewardTypes()

        # Credit only invasions are not notified
        if types.length
          query = $and: [
            {platform: platform}
            {items:
              $in: types
            }
            {items: 'invasions'}
          ]
          broadcast i.toString(), query, robot, userDB
      return

checkNews = (robot, userDB, platform) ->
  ###
  # Check for unread news and notify them to subscribed users from userDB
  #
  # @param object robot
  # @param object userDB
  # @param string platform
  ###
  robot.logger.debug 'Checking news (' + platform + ')...'
  ds.getNews platform, (err, news) ->
    if err
      robot.logger.error err
    else
      # IDs are saved in robot.brain
      notifiedNewsIds = robot.brain.get('notifiedNewsIds' + platform) or []
      robot.brain.set 'notifiedNewsIds' + platform, (n.id for n in news)

      for n in news when n.id not in notifiedNewsIds
        broadcast 'News: ' + n.toString(false),
          items: 'news'
          platform: platform
        , robot, userDB
      return

broadcast = (message, query, robot, userDB) ->
  ###
  # Broadcast a message to all subscribed users that match a query
  #
  # @param string message
  # @param object query
  # @param object robot
  # @param object userDB
  ###
  robot.logger.debug 'Broadcasting to: %s', util.inspect(query, {depth: null})
  userDB.broadcast query, (err, chatID) ->
    if err
      robot.logger.error err
    else
      robot.messageRoom chatID, message
    
