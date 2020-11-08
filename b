/****************************************************
 Grafika komputerowa, OpenGL w środowisku MS Windows
 ****************************************************/


#include <windows.h>
#include <windowsx.h>
#include <math.h>

#include <vector>

#include <gl\gl.h>
#include <gl\glu.h>

#define PI 3.1415926


struct V3 {
	float x;
	float y;
	float z;
};

using std::vector;


double win_mouseX = 0;
double win_mouseY = 0;

double mouse_horizontal = 0;
double mouse_vertical = 0;
double old_mouse_x = 0;
double old_mouse_y = 0;





//deklaracja funkcji obslugi okna
LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);

BOOL SetWindowPixelFormat(HDC hDC);
BOOL CreateViewGLContext(HDC hDC);
void RenderScene();
void CreateMaze();

int g_GLPixelIndex = 0;
HGLRC g_hGLContext = NULL;
HDC g_context = NULL;

double g_counter = 0.0;

enum GLDisplayListNames
{
	LetterFirstPlan=1,
	LetterSecondPlan=2,
	SideWalls=3,
	LineStripSecondPlan=4,
};

//funkcja Main - dla Windows
int WINAPI WinMain(HINSTANCE hInstance,
               HINSTANCE hPrevInstance,
               LPSTR     lpCmdLine,
               int       nCmdShow)
{
	MSG meldunek;		  //innymi slowy "komunikat"
	WNDCLASS nasza_klasa; //klasa głównego okna aplikacji
	HWND okno;
	static char nazwa_klasy[] = "Podstawowa";

	//Definiujemy klase głównego okna aplikacji
	//Okreslamy tu wlasciwosci okna, szczegoly wygladu oraz
	//adres funkcji przetwarzajacej komunikaty
	nasza_klasa.style         = CS_HREDRAW | CS_VREDRAW;
	nasza_klasa.lpfnWndProc   = WndProc; //adres funkcji realizującej przetwarzanie meldunków 
 	nasza_klasa.cbClsExtra    = 0 ;
	nasza_klasa.cbWndExtra    = 0 ;
	nasza_klasa.hInstance     = hInstance; //identyfikator procesu przekazany przez MS Windows podczas uruchamiania programu
	nasza_klasa.hIcon         = 0;
	nasza_klasa.hCursor       = LoadCursor(0, IDC_ARROW);
	nasza_klasa.hbrBackground = (HBRUSH) GetStockObject(GRAY_BRUSH);
	nasza_klasa.lpszMenuName  = "Menu" ;
	nasza_klasa.lpszClassName = nazwa_klasy;

    //teraz rejestrujemy klasę okna głównego
    RegisterClass (&nasza_klasa);
	
	/*tworzymy okno główne
	okno będzie miało zmienne rozmiary, listwę z tytułem, menu systemowym
	i przyciskami do zwijania do ikony i rozwijania na cały ekran, po utworzeniu
	będzie widoczne na ekranie */
 	okno = CreateWindow(nazwa_klasy, "Grafika komputerowa", WS_OVERLAPPEDWINDOW | WS_VISIBLE | WS_CLIPCHILDREN | WS_CLIPSIBLINGS,
						100, 50, 700, 700, NULL, NULL, hInstance, NULL);
	
	
	ShowWindow (okno, nCmdShow) ;
    
	//odswiezamy zawartosc okna
	UpdateWindow (okno) ;


	// GŁÓWNA PĘTLA PROGRAMU
	while (GetMessage(&meldunek, NULL, 0, 0))
     /* pobranie komunikatu z kolejki; funkcja GetMessage zwraca FALSE tylko dla
	 komunikatu wm_Quit; dla wszystkich pozostałych komunikatów zwraca wartość TRUE */
	{
		TranslateMessage(&meldunek); // wstępna obróbka komunikatu
		DispatchMessage(&meldunek);  // przekazanie komunikatu właściwemu adresatowi (czyli funkcji obslugujacej odpowiednie okno)
	}
	return (int)meldunek.wParam;
}

/********************************************************************
FUNKCJA OKNA realizujaca przetwarzanie meldunków kierowanych do okna aplikacji*/
LRESULT CALLBACK WndProc (HWND okno, UINT kod_meldunku, WPARAM wParam, LPARAM lParam)
{
	HMENU mPlik, mInfo, mGlowne;
	    	
/* PONIŻSZA INSTRUKCJA DEFINIUJE REAKCJE APLIKACJI NA POSZCZEGÓLNE MELDUNKI */
	switch (kod_meldunku) 
	{
	case WM_CREATE:  //meldunek wysyłany w momencie tworzenia okna
		{
			mPlik = CreateMenu();
			AppendMenu(mPlik, MF_STRING, 101, "&Koniec");
			mInfo = CreateMenu();
			AppendMenu(mInfo, MF_STRING, 200, "&Autor...");
			mGlowne = CreateMenu();
			AppendMenu(mGlowne, MF_POPUP, (UINT_PTR) mPlik, "&Plik");
			AppendMenu(mGlowne, MF_POPUP, (UINT_PTR) mInfo, "&Informacja");
			SetMenu(okno, mGlowne);
			DrawMenuBar(okno);

			g_context = GetDC(okno);

			if (SetWindowPixelFormat(g_context)==FALSE)
				return FALSE;

			if (CreateViewGLContext(g_context)==FALSE)
				return 0;

			CreateMaze();		// definiujemy listy tworzące labirynt

			SetTimer(okno, 1, 33, NULL);
						
			return 0;
		}

	case WM_COMMAND: //reakcje na wybór opcji z menu
		switch (wParam)
		{
			case 101: DestroyWindow(okno); //wysylamy meldunek WM_DESTROY
        			  break;
			case 200: MessageBox(okno, "Imię i nazwisko: Adrian Bieliński\nNumer indeksu: ", "Autor", MB_OK);
		}
		return 0;
	
	case WM_LBUTTONDOWN: //reakcja na lewy przycisk myszki
		{
			int x = LOWORD(lParam);
			int y = HIWORD(lParam);
			
			return 0;
		}

	case WM_PAINT:
		{
			PAINTSTRUCT paint;
			HDC kontekst;
			kontekst = BeginPaint(okno, &paint);
		
			RenderScene();			
			SwapBuffers(kontekst);

			EndPaint(okno, &paint);

			return 0;
		}

	case WM_TIMER:
	{
		InvalidateRect(okno, NULL, FALSE);
		g_counter += 0.5;
		if (g_counter > 359)
			g_counter = 0;

		return 0;
	}

	
	case WM_MOUSEMOVE:
		{
			win_mouseX = GET_X_LPARAM(lParam);
			win_mouseY = GET_Y_LPARAM(lParam);
			break;
		}
	

	case WM_SIZE:
		{
			int cx = LOWORD(lParam);
			int cy = HIWORD(lParam);

			GLsizei width, height;
			GLdouble aspect;
			width = cx;
			height = cy;
			
			if (cy==0)
				aspect = (GLdouble)width;
			else
				aspect = (GLdouble)width/(GLdouble)height;
			
			glViewport(0, 0, width, height);
			
			glMatrixMode(GL_PROJECTION);
			glLoadIdentity();
			gluPerspective(55, aspect, 1, 50.0);

			glMatrixMode(GL_MODELVIEW);
			glLoadIdentity();

			glDrawBuffer(GL_BACK);

			glEnable(GL_LIGHTING);

			glEnable(GL_DEPTH_TEST);

			return 0;
		}
  	
	case WM_DESTROY: //obowiązkowa obsługa meldunku o zamknięciu okna
		if(wglGetCurrentContext()!=NULL)
		{
			// dezaktualizacja kontekstu renderującego
			wglMakeCurrent(NULL, NULL) ;
		}
		if (g_hGLContext!=NULL)
		{
			wglDeleteContext(g_hGLContext);
			g_hGLContext = NULL;
		}

		ReleaseDC(okno, g_context);
		KillTimer(okno, 1);

		PostQuitMessage (0) ;
		return 0;
    
	default: //standardowa obsługa pozostałych meldunków
		return DefWindowProc(okno, kod_meldunku, wParam, lParam);
	}
}

BOOL SetWindowPixelFormat(HDC hDC)
{
	PIXELFORMATDESCRIPTOR pixelDesc;

	pixelDesc.nSize = sizeof(PIXELFORMATDESCRIPTOR);
	pixelDesc.nVersion = 1;
	pixelDesc.dwFlags = PFD_DRAW_TO_WINDOW |PFD_SUPPORT_OPENGL |PFD_DOUBLEBUFFER |PFD_STEREO_DONTCARE;
	pixelDesc.iPixelType = PFD_TYPE_RGBA;
	pixelDesc.cColorBits = 32;
	pixelDesc.cRedBits = 8;
	pixelDesc.cRedShift = 16;
	pixelDesc.cGreenBits = 8;
	pixelDesc.cGreenShift = 8;
	pixelDesc.cBlueBits = 8;
	pixelDesc.cBlueShift = 0;
	pixelDesc.cAlphaBits = 0;
	pixelDesc.cAlphaShift = 0;
	pixelDesc.cAccumBits = 64;
	pixelDesc.cAccumRedBits = 16;
	pixelDesc.cAccumGreenBits = 16;
	pixelDesc.cAccumBlueBits = 16;
	pixelDesc.cAccumAlphaBits = 0;
	pixelDesc.cDepthBits = 32;
	pixelDesc.cStencilBits = 8;
	pixelDesc.cAuxBuffers = 0;
	pixelDesc.iLayerType = PFD_MAIN_PLANE;
	pixelDesc.bReserved = 0;
	pixelDesc.dwLayerMask = 0;
	pixelDesc.dwVisibleMask = 0;
	pixelDesc.dwDamageMask = 0;
	g_GLPixelIndex = ChoosePixelFormat( hDC, &pixelDesc);
	
	if (g_GLPixelIndex==0) 
	{
		g_GLPixelIndex = 1;
		
		if (DescribePixelFormat(hDC, g_GLPixelIndex, sizeof(PIXELFORMATDESCRIPTOR), &pixelDesc)==0)
		{
			return FALSE;
		}
	}
	
	if (SetPixelFormat( hDC, g_GLPixelIndex, &pixelDesc)==FALSE)
	{
		return FALSE;
	}
	
	return TRUE;
}
BOOL CreateViewGLContext(HDC hDC)
{
	g_hGLContext = wglCreateContext(hDC);

	if (g_hGLContext == NULL)
	{
		return FALSE;
	}
	
	if (wglMakeCurrent(hDC, g_hGLContext)==FALSE)
	{
		return FALSE;
	}
	
	return TRUE;
}

void mouseMovement() {
	mouse_horizontal += (old_mouse_x - win_mouseX) * 0.1;
	mouse_vertical += (old_mouse_y - win_mouseY) * 0.1;
	old_mouse_x = win_mouseX;
	old_mouse_y = win_mouseY;
}

void RenderScene()
{
	GLfloat BlueSurface[] = { 0.3f, 1.0f, 0.9f, 0.8f};
	GLfloat GreenSurface[] = { 0.1f, 0.7f, 0.4f, 1.0f};

	GLfloat LightAmbient[] = { 0.1f, 0.1f, 0.1f, 0.1f };
	GLfloat LightDiffuse[] = { 0.8f, 0.8f, 0.8f, 0.8f };
	GLfloat LightPosition[] = { 0.0f, 1.0f, 1.0f, 0.0f };	


	


    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	glLightfv(GL_LIGHT0, GL_AMBIENT, LightAmbient);		//1 składowa: światło otaczające (bezkierunkowe)
	glLightfv(GL_LIGHT0, GL_DIFFUSE, LightDiffuse);		//2 składowa: światło rozproszone (kierunkowe)
	glLightfv(GL_LIGHT0, GL_POSITION, LightPosition);
	glEnable(GL_LIGHT0);

	glPushMatrix();
		
		gluLookAt(0, 3, 12 , 0, 0, 0 , 0, 1, 0);
		
		glRotatef(mouse_horizontal, 0, 1, 0);
		glRotatef(mouse_vertical, 1, 0, 0);


		glRotated(g_counter, 0, 1, 0);
		
		glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE,  GreenSurface);
		glCallList(LetterFirstPlan);

		glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, BlueSurface);
		glCallList(LetterSecondPlan);

		glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, GreenSurface);
		glCallList(LineStripSecondPlan);
		
		glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, LightDiffuse);
		glCallList(SideWalls);
		

		glTranslatef(6, 0, 1);

		glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, LightDiffuse);
		glCallList(LetterFirstPlan);

		glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, LightPosition);
		glCallList(LetterSecondPlan);

		glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, LightDiffuse);
		glCallList(LineStripSecondPlan);

		glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, GreenSurface);
		glCallList(SideWalls);

		
	
	glPopMatrix();
	
	glFlush();

}


void CreateMaze()
{

	vector<V3> out_vertices;
	vector<V3> out_vertices2;
	vector<V3> out_vertices3;

	//front
	out_vertices.push_back(V3{ 0, 0, 0 });
	out_vertices.push_back(V3{ 0, 2, 0 });
	out_vertices.push_back(V3{ 0.5, 0, 0 });
	out_vertices.push_back(V3{ 0.5, 2, 0 });
	out_vertices.push_back(V3{ 0, 2, 0 });
	out_vertices.push_back(V3{ 0.5, 2, 0 });
	out_vertices.push_back(V3{ 0.5, 1.5, 0 });
	out_vertices.push_back(V3{ 0.5, 2, 0 });
	out_vertices.push_back(V3{ 1, 2, 0 });
	out_vertices.push_back(V3{ 0.5, 1.5, 0 });
	out_vertices.push_back(V3{ 0.5, 1.5, 0 });
	out_vertices.push_back(V3{ 1, 2, 0 });
	out_vertices.push_back(V3{ 1, 1.5, 0 });
	out_vertices.push_back(V3{ 1, 2, 0 });
	out_vertices.push_back(V3{ 1, 0, 0 });
	out_vertices.push_back(V3{ 1.5, 0, 0 });
	out_vertices.push_back(V3{ 1.5, 2, 0 });
	out_vertices.push_back(V3{ 1, 2, 0 });
	out_vertices.push_back(V3{ 1, 1, 0 });
	out_vertices.push_back(V3{ 1, 0.7, 0 });
	out_vertices.push_back(V3{ 0.5, 0.7, 0 });
	out_vertices.push_back(V3{ 0.5, 1, 0 });
	out_vertices.push_back(V3{ 1, 1, 0 });
	out_vertices.push_back(V3{ 1, 0.7, 0 });


	//back
	out_vertices2.push_back(V3{ 0, 0, 0.5 });
	out_vertices2.push_back(V3{ 0, 2, 0.5 });
	out_vertices2.push_back(V3{ 0.5, 0, 0.5 });
	out_vertices2.push_back(V3{ 0.5, 2, 0.5 });
	out_vertices2.push_back(V3{ 0, 2, 0.5 });
	out_vertices2.push_back(V3{ 0.5, 2, 0.5 });
	out_vertices2.push_back(V3{ 0.5, 1.5, 0.5 });
	out_vertices2.push_back(V3{ 0.5, 2, 0.5 });
	out_vertices2.push_back(V3{ 1, 2, 0.5 });
	out_vertices2.push_back(V3{ 0.5, 1.5, 0.5 });
	out_vertices2.push_back(V3{ 0.5, 1.5, 0.5 });
	out_vertices2.push_back(V3{ 1, 2, 0.5 });
	out_vertices2.push_back(V3{ 1, 1.5, 0.5 });
	out_vertices2.push_back(V3{ 1, 2, 0.5 });
	out_vertices2.push_back(V3{ 1, 0, 0.5 });
	out_vertices2.push_back(V3{ 1.5, 0, 0.5 });
	out_vertices2.push_back(V3{ 1.5, 2, 0.5 });
	out_vertices2.push_back(V3{ 1, 2, 0.5 });
	out_vertices2.push_back(V3{ 1, 1, 0.5 });
	out_vertices2.push_back(V3{ 1, 0.7, 0.5 });
	out_vertices2.push_back(V3{ 0.5, 0.7, 0.5 });
	out_vertices2.push_back(V3{ 0.5, 1, 0.5 });
	out_vertices2.push_back(V3{ 1, 1, 0.5 });
	out_vertices2.push_back(V3{ 1, 0.7, 0.5 });

	//sides
	out_vertices3.push_back(V3{ 0, 0, 0.5 });
	out_vertices3.push_back(V3{ 0, 0, 0 });
	out_vertices3.push_back(V3{ 0, 2, 0 });
	out_vertices3.push_back(V3{ 0, 2, 0.5 });
	out_vertices3.push_back(V3{ 0, 0, 0.5 });
	out_vertices3.push_back(V3{ 0, 0, 0 });
	out_vertices3.push_back(V3{ 0, 0, 0.5 });
	out_vertices3.push_back(V3{ 0.5, 0, 0.5 });
	out_vertices3.push_back(V3{ 0, 0, 0 });
	out_vertices3.push_back(V3{ 0.5, 0, 0 });
	out_vertices3.push_back(V3{ 0.5, 0, 0.5 });
	out_vertices3.push_back(V3{ 0.5, 2, 0.5 });
	out_vertices3.push_back(V3{ 0.5, 2, 0 });
	out_vertices3.push_back(V3{ 0.5, 0, 0.5 });
	out_vertices3.push_back(V3{ 0.5, 0, 0 });
	out_vertices3.push_back(V3{ 0.5, 2, 0 });
	out_vertices3.push_back(V3{ 0, 2, 0 });
	out_vertices3.push_back(V3{ 0, 2, 0.5 });
	out_vertices3.push_back(V3{ 1.5, 2, 0 });

	out_vertices3.push_back(V3{ 1.5, 2, 0.5 });
	out_vertices3.push_back(V3{ 0, 2, 0 });

	out_vertices3.push_back(V3{ 1.5, 2, 0 });
	out_vertices3.push_back(V3{ 1.5, 2, 0.5 });
	out_vertices3.push_back(V3{ 1.5, 0, 0.5 });
	out_vertices3.push_back(V3{ 1.5, 0, 0 });

	out_vertices3.push_back(V3{ 1.5, 0, 0.5 });
	out_vertices3.push_back(V3{ 1.5, 2, 0 });
	out_vertices3.push_back(V3{ 1.5, 2, 0.5 });
	out_vertices3.push_back(V3{ 1.5, 0, 0.5 });
	out_vertices3.push_back(V3{ 1, 0, 0.5 });
	out_vertices3.push_back(V3{ 1, 0, 0 });
	out_vertices3.push_back(V3{ 1.5, 0, 0.5 });
	out_vertices3.push_back(V3{ 1.5, 0, 0 });
	out_vertices3.push_back(V3{ 1, 0, 0 });
	out_vertices3.push_back(V3{ 1.5, 0, 0.5 });

	out_vertices3.push_back(V3{ 1, 0, 0.5 });
	out_vertices3.push_back(V3{ 1, 2, 0.5 });
	out_vertices3.push_back(V3{ 1, 2, 0 });
	out_vertices3.push_back(V3{ 1, 0, 0.5 });
	out_vertices3.push_back(V3{ 1, 0, 0 });

	out_vertices3.push_back(V3{ 1, 2, 0 });
	out_vertices3.push_back(V3{ 1, 0, 0.5 });
	out_vertices3.push_back(V3{ 1, 1.5, 0.5 });

	out_vertices3.push_back(V3{ 1, 1.5, 0.5 });
	out_vertices3.push_back(V3{ 0.5, 1.5, 0 });
	out_vertices3.push_back(V3{ 0.5, 1.5, 0.5 });
	out_vertices3.push_back(V3{ 1, 1.5, 0.5 });
	out_vertices3.push_back(V3{ 1, 1.5, 0 });
	out_vertices3.push_back(V3{ 0.5, 1.5, 0 });
	out_vertices3.push_back(V3{ 1, 1.5, 0.5 });

	out_vertices3.push_back(V3{ 1, 1.5, 0.5 });
	out_vertices3.push_back(V3{ 1, 0.7, 0.5 });

	out_vertices3.push_back(V3{ 1, 0.7, 0.5 });
	out_vertices3.push_back(V3{ 0.5, 0.7, 0 });
	out_vertices3.push_back(V3{ 0.5, 0.7, 0.5 });
	out_vertices3.push_back(V3{ 1, 0.7, 0.5 });
	out_vertices3.push_back(V3{ 1, 0.7, 0 });
	out_vertices3.push_back(V3{ 0.5, 0.7, 0 });
	out_vertices3.push_back(V3{ 1, 0.7, 0.5 });


	out_vertices3.push_back(V3{ 1, 1, 0.5 });
	out_vertices3.push_back(V3{ 1, 1, 0.5 });

	out_vertices3.push_back(V3{ 1, 1, 0.5 });
	out_vertices3.push_back(V3{ 0.5, 1, 0 });
	out_vertices3.push_back(V3{ 0.5, 1, 0.5 });
	out_vertices3.push_back(V3{ 1, 1, 0.5 });
	out_vertices3.push_back(V3{ 1, 1, 0 });
	out_vertices3.push_back(V3{ 0.5, 1, 0 });
	out_vertices3.push_back(V3{ 1, 1, 0.5 });




	glNewList(LetterFirstPlan, GL_COMPILE);	// GL_COMPILE - lista jest kompilowana, ale nie wykonywana

	glBegin(GL_TRIANGLE_STRIP);		// inne opcje: GL_POINTS, GL_LINES, GL_LINE_STRIP, GL_LINE_LOOP
						// GL_TRIANGLES, GL_TRIANGLE_STRIP, GL_TRIANGLE_FAN, GL_QUAD_STRIP, GL_POLYGON
	glNormal3d(1.0, 0.0, 0.0);


	for (auto v : out_vertices) {
		glVertex3f(v.x, v.y, v.z);
	}


	glEnd();
	glEndList();


	glNewList(LetterSecondPlan, GL_COMPILE);	// GL_COMPILE - lista jest kompilowana, ale nie wykonywana

	glBegin(GL_TRIANGLE_STRIP);		// inne opcje: GL_POINTS, GL_LINES, GL_LINE_STRIP, GL_LINE_LOOP
						// GL_TRIANGLES, GL_TRIANGLE_STRIP, GL_TRIANGLE_FAN, GL_QUAD_STRIP, GL_POLYGON
	glNormal3d(1.0, 0.0, 0.0);


	for (auto v : out_vertices2) {
		glVertex3f(v.x, v.y, v.z);
	}


	glEnd();
	glEndList();




	glNewList(LineStripSecondPlan, GL_COMPILE);	// GL_COMPILE - lista jest kompilowana, ale nie wykonywana

	glBegin(GL_LINE_STRIP);		// inne opcje: GL_POINTS, GL_LINES, GL_LINE_STRIP, GL_LINE_LOOP
						// GL_TRIANGLES, GL_TRIANGLE_STRIP, GL_TRIANGLE_FAN, GL_QUAD_STRIP, GL_POLYGON
	glNormal3d(1.0, 0.0, 0.0);

	for (auto v : out_vertices2) {
		glVertex3f(v.x, v.y, v.z);
	}


	glEnd();
	glEndList();





	glNewList(SideWalls, GL_COMPILE);	// GL_COMPILE - lista jest kompilowana, ale nie wykonywana

	glBegin(GL_TRIANGLE_STRIP);		// inne opcje: GL_POINTS, GL_LINES, GL_LINE_STRIP, GL_LINE_LOOP
						// GL_TRIANGLES, GL_TRIANGLE_STRIP, GL_TRIANGLE_FAN, GL_QUAD_STRIP, GL_POLYGON
	glNormal3d(1.0, 0.0, 0.0);


	for (auto v : out_vertices3) {
		glVertex3f(v.x, v.y, v.z);
	}


	glEnd();
	glEndList();



	/*
	glNewList(Floor,GL_COMPILE);
		glBegin(GL_POLYGON);
			glNormal3d( 0.0, 1.0, 0.0);
			glVertex3d( -20, -1, -30.0);
			glVertex3d( -20, -1, 10.0);
			glVertex3d( 20, -1, 10.0);
			glVertex3d( 20, -1, -30.0);
		glEnd();
	glEndList();
	*/
}

