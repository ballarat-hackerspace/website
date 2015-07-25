//** jQuery Scroll to Top Control script- (c) Dynamic Drive DHTML code library: http://www.dynamicdrive.com.
//** Available/ usage terms at http://www.dynamicdrive.com (March 30th, 09')
//** v1.1 (April 7th, 09'):
//** 1) Adds ability to scroll to an absolute position (from top of page) or specific element on the page instead.
//** 2) Fixes scroll animation not working in Opera. 


var scrolltotop={
  //startline: Integer. Number of pixels from top of doc scrollbar is scrolled before showing control
  //scrollto: Keyword (Integer, or "Scroll_to_Element_ID"). How far to scroll document up when control is clicked on (0=top).
  setting: {startline:100, scrollto: 0, scrollduration:1000, fadeduration:[500, 100]},
  controlHTML: '<i class="fa fa-fw fa-angle-up"></i>', //HTML for control, which is auto wrapped in DIV w/ ID="topcontrol"
  anchorkeyword: '#top', //Enter href value of HTML anchors on the page that should also act as "Scroll Up" links

  state: {isvisible:false, shouldvisible:false},

  scrollup:function(){
    var dest=isNaN(this.setting.scrollto)? this.setting.scrollto : parseInt(this.setting.scrollto)
    if (typeof dest=="string" && jQuery('#'+dest).length==1) //check element set by string exists
      dest=jQuery('#'+dest).offset().top
    else
      dest=0
    this.$body.animate({scrollTop: dest}, this.setting.scrollduration);
  },

  togglecontrol:function(){
    var scrolltop=jQuery(window).scrollTop()
    this.state.shouldvisible=(scrolltop>=this.setting.startline)? true : false
    if (this.state.shouldvisible && !this.state.isvisible){
      this.$control.stop().animate({opacity:1}, this.setting.fadeduration[0])
      this.state.isvisible=true
    }
    else if (this.state.shouldvisible==false && this.state.isvisible){
      this.$control.stop().animate({opacity:0}, this.setting.fadeduration[1])
      this.state.isvisible=false
    }
  },
  
  init:function(){
    jQuery(document).ready(function($){
      var mainobj=scrolltotop
      var iebrws=document.all
      mainobj.$body=(window.opera)? (document.compatMode=="CSS1Compat"? $('html') : $('body')) : $('html,body')
      mainobj.$control=$('<div id="topcontrol">'+mainobj.controlHTML+'</div>')
        .css({opacity:0})
        .attr({title:'Scroll Back to Top'})
        .click(function(){mainobj.scrollup(); return false})
        .appendTo('body')
      if (document.all && !window.XMLHttpRequest && mainobj.$control.text()!='') //loose check for IE6 and below, plus whether control contains any text
        mainobj.$control.css({width:mainobj.$control.width()}) //IE6- seems to require an explicit width on a DIV containing text
      mainobj.togglecontrol()
      $('a[href="' + mainobj.anchorkeyword +'"]').click(function(){
        mainobj.scrollup()
        return false
      })
      $(window).bind('scroll resize', function(e){
        mainobj.togglecontrol()
      })
    })
  }
}

scrolltotop.init()
