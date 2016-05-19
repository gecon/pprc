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

#RendererCanvas.pm - Class that represent our Canvas for drawing.
#Object3D is painted here

package RendererCanvas;
use strict;
use base qw(Wx::ScrolledWindow);    #Canvas is a ScrolledWindow

#define some constants and static variables we use
use constant PI => 3.14159265358979;
use constant DANGLE => 2 * ( PI / 180 );    #angle to rotate in each key press

#WxPerl
use Wx qw(:colour :pen);
use Wx::Event qw(EVT_PAINT EVT_CLOSE EVT_KEY_DOWN EVT_SIZE);

#to time rendering
use Time::HiRes qw(gettimeofday tv_interval);

#to make deep copy of our Object3D
#implemented in Object3D now
#use Storable;

#our modules
use Object3D;
use ObjectReader::FileRaw;    #class to read object from - RAW format file
use Camera;

#parameters for requested object translations (by key presses)
our $current_theta = 0;       #theta angle rotation (degrees)
our $current_phi   = 0;       #phi angle rotation (degrees)
our $current_z     = 0;       #we do not give access for this rotation to the user
our $zoom          = 1;       #scale factor (for camera zoom)

our Object3D $gadgetObject;            #our 3D object painted on canvas
our Object3D $startingGadgetObject;    #our 3D object as it is when first reading file
our $WxApp = undef;                    #our application instance

#Constructor
sub new {
    my $class = shift;

    my $width        = shift;          #width and height parameters passed to constructor
    my $height       = shift;
    my $color        = shift;          #color to use on ray cast'
    my $smoothShades = shift;          #will use smooth shades?
    my $filename     = shift;          #file to read (RAW format)
    my $type         = shift;          #parameter "raycast" or "wireframe" canvas?

    my $self = $class->SUPER::new(@_); # call superclass constructor

    #set object fields
    $self->{x_size}       = $width;           #canvas width
    $self->{y_size}       = $height;
    $self->{colortones}   = $color;           #color of object (will be used in ray casting output)
    $self->{smoothShades} = $smoothShades;    #smooth shading?

    $self->{bitMap} = undef;                  #will hold our bitmap to draw onto
    $self->{memDC}  = undef;                  #associated with the above bitmap device context

    #set canvas background color
    $self->SetBackgroundColour(wxWHITE);

    #our events
    EVT_KEY_DOWN( $self, \&OnKeyDown );
    EVT_PAINT( $self, \&OnPaint );
    EVT_SIZE( $self, \&OnResize );

    #initialize our memory Device Context, to draw onto
    $self->{memDC} = $self->init_memDC();

    return $self if ( $type eq "raycast" );    #we don't need anything more for raycasting canvas
                                               #Some objects from http://pdelagrange.free.fr/povlab/store.html
                                               #read 3D object from file to global
    $gadgetObject = $self->loadObject($filename);

    $gadgetObject->setSmoothShades($smoothShades);

    #makes a deep copy of our object to keep it (start with the original after each request)
    $gadgetObject->storeObject();

    # Storable::dclone($gadgetObject);

    #first time drawing wireframe object to canvas
    $self->drawNewWireFrame();

    return $self;
}

sub memDC { $_[0]->{memDC} }    #return our memDC

#load object from file and initialize object and scene (lights, camera etc.)
sub loadObject {
    my $self     = shift;
    my $filename = shift;

    #taint check here!!
    my $fileReader = new ObjectReader::FileRaw($filename);
    return $fileReader->readObject();

}

#initialized our Memory Device Context to draw on this
sub init_memDC {
    my $self = shift;

    use Wx qw(:bitmap);

    #create a new device context in memory
    my $memDC = new Wx::MemoryDC();

    #get stored bitmap or create it
    my $bitmap = $self->{bitMap};
    $bitmap = new Wx::Bitmap( $self->{x_size}, $self->{y_size}, -1 )
      if ( !defined($bitmap) );
    $memDC->SelectObject($bitmap);    #select a new bitmap on memDC to draw onto

    #let's clear this DC
    my $bgColor = Wx::Colour->new( 0, 0, 0 );
    $memDC->SetBrush( new Wx::Brush( $bgColor, Wx::wxSOLID ) );
    $memDC->Clear();

    return $memDC;

}

#draw on canvas
sub draw3D {
    my $self = shift;
    my $do   = shift;    #do "raycast" or do "wireframe"

    #prepare the Client DC to draw (on UI)
    my $dc = Wx::ClientDC->new($self);
    $self->PrepareDC($dc);

    #our colors and pens
    my $color = Wx::Colour->new( 0, 0, 0 );    #foreground (rgb)
    $self->memDC->SetPen( Wx::Pen->new( $color, 1, 0 ) );    #our pen with color and size 1 (brush 0)

    #possible optimization for win32?
    $self->memDC->BeginDrawing();
    $dc->BeginDrawing();

    #Clear Memory DeviceContext, will redraw
    $self->memDC->Clear();

    #will do wireframe draw
    if ( $do eq "wireframe" ) {
        $gadgetObject->drawWireframe( $self->memDC );        #paint our gadgetObject on memory DC

        $dc->Blit( 0, 0, $self->{x_size}, $self->{y_size}, $self->memDC, 0, 0 );    #blit (copy) $memDC to visible DC
    }

    #will do raycasting
    elsif ( $do eq "raycast" ) {
        $dc->Clear();                                                               #clear the canvas on screen
        print "Will start rendering.\n";
        $gadgetObject->render( $self->memDC, $dc, $WxApp );
    }
    else {
        print "RenderCanvas::draw3D *** This should never be here!\n";
    }

    #$self->memDC->SelectObject(wxNullBitmap); #throw memDC
    $self->memDC->EndDrawing();
    $dc->EndDrawing();
}

#reset object to initial state and draw wireframe
sub resetWireFrame {
    my $self = shift;

    #revert object to starting state
    #$gadgetObject = Storable::dclone($startingGadgetObject);
    $gadgetObject->restoreObject();

    $current_theta = 0;
    $current_phi   = 0;
    $current_z     = 0;
    $zoom          = 1;

    #draw
    $self->drawNewWireFrame();
}

sub drawNewWireFrame {
    my $self = shift;

    # measure elapsed time, start counting - time tick
    my $t0 = [gettimeofday];

    #revert object to starting state
    #$gadgetObject = Storable::dclone($startingGadgetObject);
    $gadgetObject->restoreObject();

    my Camera $cam = $gadgetObject->{camera};

    $cam->setScreenWidth( $self->{x_size} );

    #print "Will render wireframe with (theta, phi, zoom) = (" .$current_theta*DANGLE .", " .$current_phi*DANGLE .", $zoom)\n";

    #orbit camera
    $cam->orbit( $gadgetObject, $current_phi * DANGLE, $current_theta * DANGLE, $zoom, "wireframe" );

    #and draw wireframe
    $self->draw3D("wireframe");

    #end counting - time tick
    my $elapsed = tv_interval($t0);
    #print "RendererCanvas::drawNewWireFrame elapsed time for drawing frame: $elapsed\n";    #print profiling info

    return;
}

#render object (ray casting)
sub render {
    my $self = shift;
    my $app  = shift;

    $WxApp = $app;

    #print "RenderCanvas::render() ... ";

    # measure elapsed time, start counting - time tick
    my $t0 = [gettimeofday];

    #create our camera
    my Camera $cam = $gadgetObject->{camera};

    #print "Will render raycasting with (theta, phi, zoom) = (" .$current_theta*DANGLE .", " .$current_phi*DANGLE .", $zoom)\n";

    #reset object
    #$gadgetObject = Storable::dclone($startingGadgetObject);
    $gadgetObject->restoreObject();

    #orbit to requested angle, zoom
    $cam->orbit( $gadgetObject, $current_phi * DANGLE, $current_theta * DANGLE, $zoom, "raycast" );

    #update object's bounding box and center (will be used in bouncing box intersection test
    $gadgetObject->getBoundingBoxAndCenter();

    #compute faces normals (not really needed here, they are right after orbiting)
    $gadgetObject->computeNormals();

    #set object colortones
    $gadgetObject->SetColorTones( $self->{colortones} );

    #set camera window width.
    $gadgetObject->{camera}->{rayCastScrW} = $self->{x_size};
    $gadgetObject->{camera}->{rayCastScrH} = $self->{y_size};

    #draw (raycasting)
    $self->draw3D("raycast");

    #end counting - time tick
    my $elapsed = tv_interval($t0);
    print "RendererCanvas::render elapsed time for ray casting: $elapsed sec\n";    #print this simple profiling info
}

#redraws wireframe on key presses
sub handleKeystrokes {
    my $self    = shift;
    my $keycode = shift;

    my $willRePaint = 0;

    #change requested, update variables of angles, zoom
    if    ( $keycode == ord('z') || $keycode == 90 ) { $current_phi++;   $willRePaint = 1; }
    elsif ( $keycode == ord('a') || $keycode == 65 ) { $current_phi--;   $willRePaint = 1; }
    elsif ( $keycode == ord('x') || $keycode == 88 ) { $current_theta++; $willRePaint = 1; }
    elsif ( $keycode == ord('s') || $keycode == 83 ) { $current_theta--; $willRePaint = 1; }
    elsif ( $keycode == ord('[') || $keycode == 91 ) { $zoom += 0.05; $willRePaint = 1; }
    elsif ( $keycode == ord(']') || $keycode == 93 ) {
        $zoom -= 0.05 unless ( $zoom <= 0 );
        $willRePaint = 1;
    }

    #render wireframe again, with new angles, zoom
    $self->OnResize() if $willRePaint == 1;
}

#event
sub OnResize {
    my ( $self, $event ) = @_;

    return if ( $self->GetName() ne "wireframe_canvas" );    #resize resulting image only on wireframe view
    my $current_w = $self->GetClientSize->GetWidth();

    $self->{x_size} = $current_w;

    # height of our screen - this is 2/3 screen (1/1.33333 = 0.7519)
    $self->{y_size} = ( $self->{x_size} * 0.7519 + 0.5 );

    #$self->SetSize($self->{x_size},$self->{y_size});

    #and draw
    $self->drawNewWireFrame();

    #$event->Skip();

}

#event
sub OnPaint {

    my $self = shift;

    my $paintDC = Wx::PaintDC->new($self);
    $self->PrepareDC($paintDC);

    #print "RendererCanvas::OnPaint()\n";

    #possible optimization for win32?
    $self->memDC->BeginDrawing();
    $paintDC->BeginDrawing();

    #clear Canvas, will paint again
    $paintDC->Clear();

    #we are implementing double buffering so, all we need is to blit our bitmap from memory to canvas Device Context
    #copy memDC->paintDC
    $paintDC->Blit( 0, 0, $self->{x_size}, $self->{y_size}, $self->memDC, 0, 0 );
    $self->Update();

    $self->memDC->EndDrawing();
    $paintDC->EndDrawing();

}

#pass event, will handing on container
sub OnKeyDown {
    my ( $self, $event ) = @_;
    $event->Skip();
}

1;
