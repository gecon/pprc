#!/usr/bin/perl -w

#
# The Perl Pure RayCaster
# Perl Pure RayCaster is a simple Raycaster written completely in Perl, without use of any external libraries (like OpenGL etc.).
# This is for educational purposes, you can study methods commonly used and easily test new things.
# Do not expect advanced features found in ray tracers and speed of compiled languages.
#
# This file is part of the Perl Pure RayCaster
#
# Author:  Giannis Economou (geconomou@gmail.com)
# Created: 5/2004. Some additions, changes and the initial public release made on 1/2006
#
#
#DISCLAIMER
#This software is distributed in the hope that it will be useful, but is provided "AS IS" WITHOUT WARRANTY OF ANY KIND,
# either expressed or implied, INCLUDING, without limitation, the implied warranties of MERCHANTABILITY and FITNESS FOR A PARTICULAR PURPOSE.
#The ENTIRE RISK as to the quality and performance of the software IS WITH YOU (the holder of the software).
# Should the software prove defective, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.
#IN NO EVENT WILL ANY COPYRIGHT HOLDER OR ANY OTHER PARTY WHO MAY CREATE, MODIFY, OR DISTRIBUTE THE SOFTWARE BE LIABLE OR RESPONSIBLE TO YOU
# OR TO ANY OTHER ENTITY FOR ANY KIND OF DAMAGES (no matter how awful - not even if they arise from known or unknown flaws in the software).
#
#Please refer to 'Perl Pure RayCaster' site and to the Artistic License that came with your Perl distribution for more details.
#
#

use strict;
use warnings;

use Wx;

package main;
use constant VERSION => scalar "1.0b";    #Pure Perl RayCaster version

use Getopt::Std;

#some defaults
our $file          = "gadget.raw";
our $rayCastWidth  = 266;
our $rayCastHeight = 200;
our $castColor     = "blue";
our $smoothShades  = 0;

getOptions();                             #parse user Options

our $smoothShadesText = ( $smoothShades == 1 ? " (smooth shading)" : "" );
print "\nPure Perl RayCaster: Will read file: $file\n";
print
  "Pure Perl RayCaster: Will ray cast using color $castColor$smoothShadesText on a ($rayCastWidth x $rayCastHeight) window. \n";

unless ( ( -e $file ) && ( -r $file ) ) {
    die "Can not read file $file. Please check that file exists and is readable.\n";
}

my $wxobj = PurePerlRayCaster->new();     # new application
$wxobj->MainLoop;

#gets user options
sub getOptions {
    my %options = ();

    #my $version = &{PurePerlRayCaster::VERSION};
    #my $version = @{PurePerlRayCaster::VERSION}};
    #my $version = &{PurePerlRayCaster::VERSION};

    $Getopt::Std::STANDARD_HELP_VERSION = 1;

    our $usage = "Usage:
\tpureRayCaster.pl [-s] [-f filename] [-c colorname] [-w width]\n
\twhere\n
\ts: flag to turn on smooth shading (slower)
\tfilename: the file (RAW format) to read
\tcolorname: red or green or blue
\twidth: ray casting window width in pixels (20 - 1024)
\tOptions may be merged together.  -- stops processing of options.
\t
Pure Perl RayCaster, a simple ray casting application for educational purposes.
Look at Pure Perl RayCaster web site for more info.
This software is available under the Artistic License.
";

    sub VERSION_MESSAGE    { print "Pure Perl RayCaster @{[ VERSION ]}\n"; }
    sub main::HELP_MESSAGE { print $usage; }

    getopts( 'sf:c:w:', \%options );

    #parse user specified
    #RAW file
    my $errorInArgs = 0;
    if ( exists( $options{f} ) ) {
        $errorInArgs = 1;
        if ( defined( $options{f} ) && $options{f} ne "1" ) {
            $file        = $options{f};
            $errorInArgs = 0;
        }
    }
    die($usage) if ($errorInArgs);

    #smooth shades
    if ( exists( $options{s} ) ) {
        $smoothShades = 1;
    }

    #color
    if ( exists( $options{c} ) ) {
        $errorInArgs = 1;
        if ( defined( $options{c} ) && $options{c} ne "1" ) {
            if ( $options{c} eq "blue" || $options{c} eq "red" || $options{c} eq "green" ) {
                $castColor   = $options{c};
                $errorInArgs = 0;
            }
        }
    }
    die($usage) if ($errorInArgs);

    #raycasting frame width
    if ( exists( $options{w} ) ) {
        $errorInArgs = 1;
        if ( defined( $options{w} ) && $options{w} ne "1" ) {
            if ( $options{w} =~ /^\d+$/ ) {
                if ( $options{w} >= 20 && $options{w} <= 1024 ) {
                    $rayCastWidth  = $options{w};
                    $rayCastHeight =
                      int( $rayCastWidth * 0.7519 + 0.5 );    # height of our screen - this is 2/3 screen (1/1.33333 = 0.7519)
                    $errorInArgs = 0;
                }
            }
        }
    }
    die($usage) if ($errorInArgs);
}

##########################################################################
# PerlPureRayCaster is our application
#We set the two frames in use (one for raycasting rendering - RenderFrame - and one for wireframe - WireFrame - here
package PurePerlRayCaster;

use base qw(Wx::App);    #Inherit from Wx::App
use Wx qw(wxDEFAULT_FRAME_STYLE);

sub OnInit {
    my $self = shift;

    my $frame = WireFrame->new(
        undef,                        # Parent window
        -1,                           # Window id (auto)
        'The Pure Perl Raycaster',    # Title
        [ 25,  25 ],                  # position X, Y
        [ 650, 540 ],                 # size X, Y
        wxDEFAULT_FRAME_STYLE, "The Pure Perl Raycaster"
    );

    my $rendframe = RenderFrame->new(
        $frame,                       # Parent window
        -1,                           # Window id
        'Ray Casting output',         # Title
        [ 670, 20 ],                  # position X, Y
                                      #[ 700, 75 ],                 # size X, Y
        [ $rayCastWidth + 17, $rayCastHeight + 37 ],    # size X, Y
        wxDEFAULT_FRAME_STYLE, "Ray Casting output"
    );

    $frame->SetIcon( Wx::GetWxPerlIcon() );             #set the Wx icon to frame

    $self->SetTopWindow($frame);
    $rendframe->Show(1);                                # Show the raycastframe
    $frame->Show(1);                                    # Show the frame
    $frame->SetFocus();                                 #give focus to frame

    $self->{FRAME}       = $frame;                      #hold $frame as a SimpleRenderer property
    $self->{RENDERFRAME} = $rendframe;                  #hold $frame as a SimpleRenderer property

    $$wxobj->{HALT} = 1;                                #for halting rendering

    return 1;
}

sub rendframe { $_[0]->{RENDERFRAME} }                  #returns $rendframe instance
sub frame     { $_[0]->{FRAME} }                        #returns $frame instance

###########################################################
#This is the frame for raycasting
package RenderFrame;

use base qw(Wx::Frame);                                 #Inherit from Wx::Frame
use Wx qw(:sizer);
use Wx::Event qw(EVT_CLOSE);                            #events to use

use RendererCanvas;

sub new {
    my $class = shift;

    my $self  = $class->SUPER::new(@_);                 # call the superclass' constructor
    my $panel = Wx::Panel->new(
        $self,                                          # parent
        -1                                              # id
    );

    my $casting_canvas =
      RendererCanvas->new( $rayCastWidth, $rayCastHeight, $castColor, $smoothShades, $file, "raycast", $panel, -1 )
      ;                                                 #our RendererCanvas for raycasting

    #disable scrollbars
    $casting_canvas->SetVirtualSize( 20, 20 );          #(set low virtual size)

    my $top = Wx::BoxSizer->new(wxVERTICAL);
    $top->Add( $casting_canvas, 1, wxGROW | wxALL, 5 );    #canvas
    $panel->SetSizer($top);

    $panel->SetAutoLayout(1);

    $self->SetIcon( Wx::GetWxPerlIcon() );

    #events
    #EVT_KEY_DOWN( $self,      \&OnKeyDown );
    #EVT_KEY_DOWN( $panel,   \&OnKeyDown );
    #EVT_KEY_DOWN( $casting_canvas,   \&OnKeyDown );
    EVT_CLOSE( $self, \&OnExit );

    $self->{CASTING_CANVAS} = $casting_canvas;

    return $self;

}

sub OnExit {
    my ( $self, $event ) = @_;

    #just hide it, do not destroy it
    $wxobj->{HALT} = 1;    #for halting rendering
    $self->Show(0);        #hide it, but
    $event->Veto();        #do not allow window destroy
}

#sub OnKeyDown {
#    my ( $self, $event ) = @_;
#		my $keycode = $event->GetKeyCode();
# 		$wxobj->frame->canvas->drawNewWireFrame($keycode);
#}

sub casting_canvas { $_[0]->{CASTING_CANVAS}; }    #returns $our canvas instance

###########################################################
# WireFrame is the frame for wireframe rendering
# WireFrame extends the Frame class to our needs
package WireFrame;

use base qw(Wx::Frame);                            #Inherit from Wx::Frame
use Wx qw(:sizer :staticline);
use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_KEY_DOWN EVT_SIZE);

use RendererCanvas;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);            # call the superclass' constructor
    my $panel = Wx::Panel->new(
        $self,                                     # parent
        -1                                         # id
    );

    my $canvas = RendererCanvas->new( 1640, 1200, $castColor, $smoothShades, $file, "wireframe", $panel );
    $canvas->SetVirtualSize( 20, 20 );             #disable scrollbars (set low virtual size)
    $canvas->SetName("wireframe_canvas");          #we give a name to use in in class

    my $btnReset = Wx::Button->new(
        $panel,                                    # parent
        2,                                         # id
        "Reset",                                   # label
    );

    my $btnRender = Wx::Button->new(
        $panel,                                    # parent
        1,                                         # id
        "Render",                                  # label
    );

    my $btnStop = Wx::Button->new(
        $panel,                                    # parent
        3,                                         # id
        "Stop",                                    # label
    );
    my $btnExit = Wx::Button->new(
        $panel,                                    # parent
        4,                                         # id
        "Exit",                                    # label
    );

    my $legendTxt = Wx::StaticText->new(
        $panel,                                                          # parent
        1,                                                               # id
        "Camera Orbit Controls (keys): \n" . "Z, A \t X, S \t ], [\n"    # label
    );

    my $titleTxt = Wx::StaticText->new(
        $panel,                                                          # parent
        1,                                                               # id
                                                                         # label
        "The Pure Perl Raycaster (v" . main::VERSION . ")",
    );

    $self->{CANVAS} = $canvas;

    my $top = Wx::BoxSizer->new(wxVERTICAL);
    $top->Add( Wx::StaticLine->new( $panel, 1 ), 0, wxGROW );            #a horizontal line
    $top->Add( $canvas, 1, wxGROW | wxALL, 5 );                          #canvas
    $top->Add( Wx::StaticLine->new( $panel, 1 ), 0, wxGROW );            #a horizontal line

    #frame bottom
    my $bottomSizer = Wx::BoxSizer->new(wxHORIZONTAL);
    $top->Add( $bottomSizer, 0, wxGROW );

    #frame bottom contents

    #buttons
    my $btnSizer = Wx::BoxSizer->new(wxHORIZONTAL);
    $btnSizer->Add( $btnReset,  0, wxALL, 3 );
    $btnSizer->Add( $btnRender, 0, wxALL, 3 );
    $btnSizer->Add( $btnStop,   0, wxALL, 3 );
    $btnSizer->Add( $btnExit,   0, wxALL, 3 );

    #$btnReset->SetDefault();

    #left panel with buttons and title
    my $leftPanel = Wx::BoxSizer->new(wxVERTICAL);
    $leftPanel->Add( $btnSizer, 0, wxGROW | wxALL, 3 );
    $leftPanel->Add( $titleTxt, 0, wxGROW | wxALL, 3 );

    $bottomSizer->Add( $leftPanel, 0, wxGROW | wxALL, 3 );

    #legend
    $bottomSizer->Add( Wx::StaticLine->new( $panel, 1, [ -1, -1 ], [ -1, 100 ], wxLI_VERTICAL ), 0 );
    $bottomSizer->Add( $legendTxt, 1, wxGROW | wxALL, 3 );

    $panel->SetSizer($top);

    $panel->SetFocus();
    $panel->SetAutoLayout(1);

    #events
    #buttons
    EVT_BUTTON( $self, $btnExit,   \&OnExit );
    EVT_BUTTON( $self, $btnRender, \&OnRender );
    EVT_BUTTON( $self, $btnReset,  \&OnReset );
    EVT_BUTTON( $self, $btnStop,   \&OnStop );
    EVT_CLOSE( $self, \&OnExit );

    #keyboard
    EVT_KEY_DOWN( $self, \&OnKeyDown );

    #EVT_KEY_DOWN( $btnRender, \&OnKeyDown );
    EVT_KEY_DOWN( $btnReset, \&OnKeyDown );
    EVT_KEY_DOWN( $btnExit,  \&OnKeyDown );
    EVT_KEY_DOWN( $btnStop,  \&OnKeyDown );
    EVT_KEY_DOWN( $panel,    \&OnKeyDown );
    EVT_KEY_DOWN( $canvas,   \&OnKeyDown );
    EVT_KEY_DOWN( $self,     \&OnKeyDown );

    #resize
    EVT_SIZE( $self, \&OnResize );

    return $self;
}

sub canvas { $_[0]->{CANVAS} }    #returns $our canvas instance

#Events implementations

sub OnResize {
    my ( $self, $event ) = @_;

    #
    $event->Skip();
}

sub OnExit {
    my ( $self, $event ) = @_;
    $wxobj->{HALT} = 1;
    $self->Destroy;
    $event->Skip();
}

sub OnStop {
    my ( $self, $event ) = @_;

    #$self->Destroy;
    $wxobj->{HALT} = 1;
    $event->Skip();
}

sub OnReset {
    my ( $self, $event ) = @_;
    $wxobj->frame->canvas->resetWireFrame();    #send this to our canvas
}

sub OnRender {
    my ( $self, $event ) = @_;

    $wxobj->rendframe->Show(1);

    #$wxobj->rendframe->Raise;
    $wxobj->rendframe->SetFocus;                #give focus to frame
    $wxobj->{HALT} = 0;                         #will become 1, in case a halt is requested;
    $wxobj->rendframe->casting_canvas->render($wxobj);

    $event->Skip();
}

sub OnKeyDown {
    my ( $self, $event ) = @_;

    my $keycode = $event->GetKeyCode();

    #print "pressed: " .$keycode." (ord: " . ord('z') .")\n";

    $wxobj->frame->canvas->handleKeystrokes($keycode);

}
