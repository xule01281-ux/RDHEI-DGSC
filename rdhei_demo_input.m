function I=rdhei_demo_input()
%RDHEI_DEMO_INPUT Deterministic synthetic grayscale image, freely redistributable.
[x,y]=meshgrid(0:255,0:255);
I=uint8(round(35+.32*x+.24*y+18*sin(x/18).*cos(y/23)+ ...
    35*((x-135).^2+(y-125).^2<48^2)));
end
