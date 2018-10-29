FROM centos

COPY dce-app-entrypoint /work/dce-app-entrypoint
COPY echo.sh /work/echo.sh

ENV DAE_NETWORK='mac'
ENV DAE_SEGMENT='^172\.17\.\d{1,3}.\d{1,3}$'

ENTRYPOINT ["/work/dce-app-entrypoint"]

CMD ["sh" , "/work/echo.sh"]