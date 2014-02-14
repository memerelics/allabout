fs   = require 'fs'
sys  = require 'system'
page = require('webpage').create()
# Any console message from a web page, including from the code inside evaluate(),
# will not be displayed by default. To override this behavior, use the onConsoleMessage callback.
page.onConsoleMessage = (msg) -> console.log msg
page.settings.userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:26.0) Gecko/20100101 Firefox/26.0'

extractBody = (html) -> html.match(/<body[^>]*>([\w|\W]*)<\/body>/im)[1]

f = fs.open('./conf.json', 'r')
conf = JSON.parse(f.read())
conf.debug     = false

fillMeta = (meta) ->
  document.querySelector('input[name=txt_TitleShort]').value = meta.titleShort
  document.querySelector('input[name=txt_Title]').value = meta.title
  document.querySelector('textarea[name=txt_MetaDescription]').value = meta.abstract
  document.querySelector('textarea[name=txt_MetaKeywords]').value = meta.keywords


#------- update --------#
#-----------------------#
updateArticle = (page) ->
  page.onLoadFinished = -> # 記事一覧画面
    page.render('aa4.png') if conf.debug
    page.evaluate((conf) ->
      elems = document.getElementsByTagName('a')
      for elem in elems
        if elem.innerHTML == conf.articleId
          targ = elem
          break
      ((el, etype) ->
        if el.fireEvent
          el.fireEvent 'on' + etype
        else
          evObj = document.createEvent('Events')
          evObj.initEvent etype, true, false
          el.dispatchEvent evObj
      )(targ, 'click')
    , conf)
    page.onLoadFinished = -> # 記事編集画面
      page.render('aa5.png') if conf.debug
      page.evaluate (conf, func) ->
        if conf.meta?
          console.log JSON.stringify(conf.meta, null, "    ")
          func(conf.meta)
        if conf.content? && conf.content.length > 0
          document.querySelector('textarea[name=txt_Article]').value = conf.content
        document.form.submit()
      , conf, fillMeta
      page.onLoadFinished = -> # 記事を保存しました
        page.render('aa6.png') if conf.debug
        page.evaluate ->
          buttonHTML = document.querySelector('input[name=preview]').outerHTML
          jumpPath   = buttonHTML.replace(/.*onclick="javascript:movePage\('\/\/(.*)',.*/, "$1")
          jumpURL    = "https://#{jumpPath}"
          console.log("https://#{jumpPath}")
        phantom.exit()


#------- create --------#
#-----------------------#
createArticle = (page) ->
  page.onLoadFinished = -> # 記事一覧画面
    page.render('aa4.png') if conf.debug
    page.evaluate ->
      document.getElementsByName('newcontent')[0].click()
    page.onLoadFinished = -> # 記事新規作成画面
      page.render('aa5.png') if conf.debug
      page.evaluate (conf, func) ->
        console.log JSON.stringify(conf.meta, null, "    ")
        func(conf.meta)
        document.querySelector('textarea[name=txt_Article]').value = '--' # tmp article
        document.form.submit()
      , conf, fillMeta
      page.onLoadFinished = -> # 記事を保存しました
        page.render('aa6.png') if conf.debug
        page.evaluate -> # TODO: same code. make it DRY.
          buttonHTML = document.querySelector('input[name=preview]').outerHTML
          jumpPath   = buttonHTML.replace(/.*onclick="javascript:movePage\('\/\/(.*)',.*/, "$1")
          jumpURL    = "https://#{jumpPath}"
          console.log("https://#{jumpPath}")
        phantom.exit()


#-------- list ---------#
#-----------------------#
listArticles = (page) ->
  page.onLoadFinished = -> # 記事一覧画面
    page.evaluate ->
      listTable = document.getElementsByClassName('table2')[1]
      for row in listTable.getElementsByTagName('tr')
        continue if row.getElementsByTagName('td')[0].innerHTML.match(/No/)
        articleId  = row.getElementsByTagName('td')[1].children[0].innerText
        article    = row.getElementsByTagName('td')[2].children[0]
        title      = article.text
        previewURL = article.href
        console.log "#{articleId}: #{title} -- #{previewURL}"
    phantom.exit()


# TODO: make click function DRY
page.open 'https://gmtool.allabout.co.jp/g_login/index', (status) ->
  page.render('aa1.png') if conf.debug
  page.evaluate((conf) ->
    unless document.querySelector('input[name=guideid]')
      console.log "maintenance"
    else
      document.querySelector('input[name=guideid]').value = conf.guideid
      document.querySelector('input[name=passwd]').value = conf.passwd
      document.querySelector('form').submit()
  , conf)

  page.onLoadFinished = -> # ガイドテーマを選択, 移動
    phantom.exit() if page.url.match(/maintenance/)
    page.render('aa2.png') if conf.debug
    page.evaluate((conf) ->
      document.querySelector('#guidesiteid').value = conf.guidesiteid
      document.getElementsByClassName('btn_cgs')[0].click()
    , conf)

    page.onLoadFinished = -> # メニューから「コンテンツ管理」を選択
      page.render('aa3.png') if conf.debug
      page.evaluate ->
        elem = document.getElementsByClassName('menu_index')[0].children[0].childNodes[0]
        ((el, etype) ->
          if el.fireEvent
            el.fireEvent 'on' + etype
          else
            evObj = document.createEvent('Events')
            evObj.initEvent etype, true, false
            el.dispatchEvent evObj
        )(elem, 'click')


      switch sys.args[1]
        # $ phantomjs upload.coffee new metadata.json
        when "new","create"
          conf.meta = JSON.parse(fs.open(sys.args[2], 'r').read())
          createArticle(page)

        # $ phantomjs upload.coffee update <articleId> article.html
        when "update"
          conf.articleId = sys.args[2]
          conf.content   = extractBody(fs.open(sys.args[3], 'r').read())
          jsonFile = sys.args[3].replace(/(.*)\.html/, "$1.json")
          if fs.isFile(jsonFile) && fs.isReadable(jsonFile)
            conf.meta = JSON.parse(fs.open(jsonFile, 'r').read())
          updateArticle(page)

        # $ phantomjs upload.coffee list
        when "list"
          listArticles(page)

        else
          console.log 'usage: $ phantomjs upload.coffee <cmd> args...'
          console.log '       e.g. $ phantomjs upload.coffee new metadata.json'
          console.log '            $ phantomjs upload.coffee update <articleId> article.html'
          phantom.exit()

